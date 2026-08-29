#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
bench=$(cd "$(dirname "$0")" && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
src=${LIBDATRIE_SOURCE:-"$root/../ae-libs/libdatrie"}
work=${WORK:-"$root/build/ae-libdatrie"}
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_commit=45e981da7cd1d448663d901f2c1e180401ce09f1
tests=(test_walk test_iterator test_store-retrieve test_file test_serialization test_nonalpha test_null_trie test_term_state test_byte_alpha test_byte_list)

actual_commit=$(git -C "$src" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "libdatrie source must be v0.2.14 at $expected_commit" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/host" "$work/guest" "$work/dump" "$work/results"
git -C "$src" archive "$expected_commit" | tar -x -C "$work/source"
(cd "$work/source" && autoreconf -fi > "$work/results/autoreconf.log" 2>&1)

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/datrie" > "$work/dump/setjmp-audit.txt"; then
    echo "libdatrie production source uses a forbidden non-local jump" >&2
    exit 1
fi

(cd "$work/host" && "$work/source/configure" --disable-static --disable-doxygen-doc)
(cd "$work/host" && bear --output compile_commands.json -- make -j"$jobs" check \
    > "$work/results/native-check.log" 2>&1)
(cd "$work/guest" && \
    CC="$devkit/bin/x86_64-linux-gnu-clang" \
    CFLAGS="--sysroot=$devkit/x86_64/sysroot -O2" \
    LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
    "$work/source/configure" --host=x86_64-linux-gnu --disable-static --disable-doxygen-doc)
(cd "$work/guest" && make -j"$jobs" check TESTS= \
    > "$work/results/guest-build.log" 2>&1)

host_lib=$(readlink -f "$work/host/datrie/.libs/libdatrie.so")
guest_lib=$(readlink -f "$work/guest/datrie/.libs/libdatrie.so")
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
file "$host_lib" "$guest_lib" > "$work/dump/file.txt"

: > "$work/dump/guest-undefined.txt"
for test_name in "${tests[@]}"; do
    test_bin="$work/guest/tests/.libs/$test_name"
    file "$test_bin" >> "$work/dump/file.txt"
    "$nm" -D --undefined-only --just-symbol-name "$test_bin" \
        | sed 's/@.*//' >> "$work/dump/guest-undefined.txt"
done
sort -u -o "$work/dump/guest-undefined.txt" "$work/dump/guest-undefined.txt"
"$nm" -D --defined-only --format=posix "$host_lib" \
    | awk '$2 == "T" || $2 == "W" { name = $1; sub(/@.*/, "", name); print name }' \
    | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
    > "$work/dump/functions.txt"
printf '[Function]\n' > "$work/dump/Symbols.conf"
cat "$work/dump/functions.txt" >> "$work/dump/Symbols.conf"

"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" \
    -p "$work/host" \
    -o "$work/dump/Desc.dump.h"

"$devkit/bin/LoreMakeThunk.py" \
    --name datrie \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -I"$work/source"

run_full() {
    env LD_LIBRARY_PATH="$devkit/lib" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E "LD_LIBRARY_PATH=$work/guest/datrie/.libs" "$@"
}

run_hecate() {
    env LD_LIBRARY_PATH="$devkit/lib:$work/host/datrie/.libs:$work/thunk" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E LD_BIND_NOW=1 \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" "$@"
}

for lane in hecate; do
    output="$work/results/$lane.log"
    : > "$output"
    start=$(date +%s%N)
    for test_name in "${tests[@]}"; do
        echo "RUN $test_name" >> "$output"
        if [[ "$lane" == qemu ]]; then
            (cd "$work/guest/tests" && run_full ".libs/$test_name") >> "$output" 2>&1
        else
            (cd "$work/guest/tests" && run_hecate ".libs/$test_name") >> "$output" 2>&1
        fi
        echo "PASS $test_name" >> "$output"
    done
    end=$(date +%s%N)
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
    sed -E 's/0x[0-9a-fA-F]+/<PTR>/g' "$output" > "$work/results/$lane.normalized"
done

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": %s\n}\n' \
    "$actual_commit" "$function_count" "${#tests[@]}" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
