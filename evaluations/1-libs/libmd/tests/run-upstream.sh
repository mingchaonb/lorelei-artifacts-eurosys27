#!/usr/bin/env bash
set -euo pipefail
: "${DEVKIT:?}"
: "${QEMU:?}"
: "${SOURCE:?}"
: "${WORK:?}"
: "${BENCH:?}"
devkit=$DEVKIT
qemu=$QEMU
src=$SOURCE
work=$WORK
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
mkdir -p "$work" "$work/dump" "$work/results"
if grep -RInE --include='*.c' --include='*.h' \
    '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' "$src/src" \
    > "$work/dump/setjmp-audit.txt"; then
    echo "libmd production source uses a forbidden non-local jump" >&2
    exit 1
fi

cmake -E remove_directory "$work/source"
cmake -E remove_directory "$work/host"
cmake -E remove_directory "$work/guest"
mkdir -p "$work/source" "$work/host" "$work/guest"
cmake -E copy_directory "$src" "$work/source"
printf '1.2.0\n' > "$work/source/.dist-version"
(cd "$work/source" && ./autogen > "$work/results/autoreconf.log" 2>&1)

(cd "$work/host" && "$work/source/configure" --disable-static CFLAGS=-O2)
(cd "$work/host" && bear --output compile_commands.json -- make -j"$jobs" check \
    > "$work/results/native-check.log" 2>&1)
(cd "$work/guest" && \
    CC="$devkit/bin/x86_64-linux-gnu-clang" \
    CFLAGS="--sysroot=$devkit/x86_64/sysroot -O2" \
    LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
    "$work/source/configure" --host=x86_64-linux-gnu --disable-static)
(cd "$work/guest" && make -j"$jobs" check \
    > "$work/results/guest-build-check.log" 2>&1)

host_lib="$work/host/src/.libs/libmd.so.0.2.0"
guest_lib="$work/guest/src/.libs/libmd.so.0.2.0"
tests=(md2 md4 md5 rmd160 sha1 sha2 sha3)

readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
file "$host_lib" "$guest_lib" > "$work/dump/file.txt"

: > "$work/dump/guest-undefined.txt"
for test_name in "${tests[@]}"; do
    test_bin="$work/guest/test/.libs/$test_name"
    file "$test_bin" >> "$work/dump/file.txt"
    readelf -d "$test_bin" > "$work/dump/$test_name-dynamic.txt"
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

version_map="$work/dump/guest-version.map"
: > "$version_map"
for version in LIBMD_0.0 LIBMD_0.1 LIBMD_0.2; do
    echo "$version {" >> "$version_map"
    echo 'global:' >> "$version_map"
    while read -r function_name; do
        if readelf -Ws "$guest_lib" | awk -v function_name="$function_name" \
            -v version="$version" \
            '$8 == function_name "@@" version { found = 1 } END { exit !found }'; then
            echo "  $function_name;" >> "$version_map"
        fi
    done < "$work/dump/functions.txt"
    case "$version" in
        LIBMD_0.0)
            printf 'local:\n  *;\n};\n' >> "$version_map"
            ;;
        LIBMD_0.1)
            echo '} LIBMD_0.0;' >> "$version_map"
            ;;
        LIBMD_0.2)
            echo '} LIBMD_0.1;' >> "$version_map"
            ;;
    esac
done

"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" \
    -p "$work/host" \
    -o "$work/dump/Desc.dump.h"

"$devkit/bin/LoreMakeThunk.py" \
    --name md \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$BENCH/Desc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    --gtl-arg="-Wl,--version-script=$version_map" \
    -- \
    -I"$work/source/include" \
    -I"$work/host"

: > "$work/results/native.log"
: > "$work/results/hecate.log"
native_start=$(date +%s%N)
for test_name in "${tests[@]}"; do
    echo "RUN $test_name" >> "$work/results/native.log"
    env LD_LIBRARY_PATH="$work/host/src/.libs" \
        "$work/host/test/.libs/$test_name" \
        >> "$work/results/native.log" 2>&1
    echo "PASS $test_name" >> "$work/results/native.log"
done
native_end=$(date +%s%N)

hecate_start=$(date +%s%N)
for test_name in "${tests[@]}"; do
    echo "RUN $test_name" >> "$work/results/hecate.log"
    env LD_LIBRARY_PATH="$devkit/lib:$work/host/src/.libs:$work/thunk" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E LD_BIND_NOW=1 \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" \
        "$work/guest/test/.libs/$test_name" \
        >> "$work/results/hecate.log" 2>&1
    echo "PASS $test_name" >> "$work/results/hecate.log"
done
hecate_end=$(date +%s%N)

awk -v start="$native_start" -v end="$native_end" \
    'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
    > "$work/results/native.time"
awk -v start="$hecate_start" -v end="$hecate_end" \
    'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
    > "$work/results/hecate.time"

cmp "$work/results/native.log" "$work/results/hecate.log"
sha256sum "$work/results/native.log" "$work/results/hecate.log" \
    > "$work/results/output.sha256"

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": %s\n}\n' \
    "90c4f432134c608c7e2b4dd0a1d7ca5c40b92c7a" "$function_count" "${#tests[@]}" \
    > "$work/results/summary.json"

cat "$work/results/summary.json"
cat "$work/results/native.time" "$work/results/hecate.time"
