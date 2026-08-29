#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
bench=$(cd "$(dirname "$0")" && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
src=${JSONC_SOURCE:-"$root/../ae-libs/json-c"}
work=${WORK:-"$root/build/ae-json-c"}
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_commit=aa716cd8d663c976b99b0f30f102ee1d8ef63146

actual_commit=$(git -C "$src" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "json-c source must be json-c-0.19-20260627 at $expected_commit" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/host" "$work/guest" "$work/dump" "$work/results"
git -C "$src" archive "$expected_commit" | tar -x -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source"/*.c > "$work/dump/setjmp-audit.txt"; then
    echo "json-c production source uses a forbidden non-local jump" >&2
    exit 1
fi

# The upstream shell tests launch their test executables themselves. Add a runner only to the
# archived build copy so both lanes execute the same x86_64 binaries through QEMU.
sed -i \
    's#eval "\\"${top_builddir}/${TEST_COMMAND}"\\"#if [ -n "${JSONC_TEST_RUNNER:-}" ]; then TEST_PREFIX="\\"${JSONC_TEST_RUNNER}\\" "; else TEST_PREFIX=""; fi\n\teval "${TEST_PREFIX}\\"${top_builddir}/${TEST_COMMAND}\\""#' \
    "$work/source/tests/test-defs.sh"

common_cmake=(
    -G Ninja
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_STATIC_LIBS=OFF
    -DBUILD_TESTING=ON
    -DBUILD_APPS=ON
    -DDISABLE_THREAD_LOCAL_STORAGE=ON
    -DDISABLE_WERROR=ON
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

CC=clang-20 cmake -S "$work/source" -B "$work/host" "${common_cmake[@]}"
cmake --build "$work/host" -j"$jobs"
(cd "$work/host" && USE_VALGRIND=0 ctest --output-on-failure -j1 \
    > "$work/results/native-check.log" 2>&1)

CC="$devkit/bin/x86_64-linux-gnu-clang" \
    cmake -S "$work/source" -B "$work/guest" "${common_cmake[@]}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_SYSROOT="$devkit/x86_64/sysroot"
cmake --build "$work/guest" -j"$jobs" \
    > "$work/results/guest-build.log" 2>&1

host_lib=$(readlink -f "$work/host/libjson-c.so")
guest_lib=$(readlink -f "$work/guest/libjson-c.so")
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
file "$host_lib" "$guest_lib" > "$work/dump/file.txt"

mapfile -t guest_bins < <(find "$work/guest/tests" "$work/guest/apps" \
    -maxdepth 1 -type f -perm -111 | sort)
: > "$work/dump/guest-undefined.txt"
for test_bin in "${guest_bins[@]}"; do
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
    --name json-c \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    --htl-arg=-DLORE_THUNK_CALLBACK_REPLACE \
    --gtl-arg=-DLORE_THUNK_CALLBACK_REPLACE \
    --gtl-arg="-Wl,--undefined-version" \
    --gtl-arg="-Wl,--version-script=$work/source/json-c.sym" \
    -- \
    -I"$work/host" \
    -I"$work/source"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name errno-shim \
    -o "$work/thunk-errno-shim" \
    --lib "$host_libc" \
    --soname errno-shim.so \
    --symbols "$bench/ErrnoSymbols.conf" \
    --desc "$bench/ErrnoDesc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -D_GNU_SOURCE
ln -sf "$host_libc" "$work/thunk-errno-shim/liberrno-shim.so"

test_count=$(cd "$work/guest" && ctest -N | sed -n 's/^Total Tests: //p')
for lane in hecate; do
    output="$work/results/$lane.log"
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (cd "$work/guest" && \
            USE_VALGRIND=0 JSONC_TEST_RUNNER="$work/qemu-wrapper.sh" \
            QEMU="$qemu" DEVKIT="$devkit" GUEST_LIB_DIR="$work/guest" \
            ctest --output-on-failure -j1) > "$output" 2>&1
    else
        (cd "$work/guest" && \
            USE_VALGRIND=0 JSONC_TEST_RUNNER="$work/qemu-wrapper.sh" \
            QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
            HOST_LIB_DIR="$work/host" THUNK_DIR="$work/thunk" \
            ERRNO_SHIM_DIR="$work/thunk-errno-shim" \
            ctest --output-on-failure -j1) > "$output" 2>&1
    fi
    end=$(date +%s%N)
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
    sed -E \
        -e 's/[0-9]+\.[0-9]+ sec/<TIME> sec/g' \
        -e 's/Total Test time \(real\) = +[0-9]+\.[0-9]+ sec/Total Test time (real) = <TIME> sec/' \
        "$output" > "$work/results/$lane.normalized"
done

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": %s\n}\n' \
    "$actual_commit" "$function_count" "$test_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
