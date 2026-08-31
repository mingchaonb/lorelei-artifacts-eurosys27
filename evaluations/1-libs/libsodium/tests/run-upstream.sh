#!/usr/bin/env bash

set -euo pipefail

tlc_wrapper=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_common" && pwd)/lore-make-thunk.py

: "${LORELEI_DEVKIT:?LORELEI_DEVKIT is required}"
: "${QEMU:?QEMU is required}"
: "${LIBSODIUM_SOURCE:?LIBSODIUM_SOURCE is required}"
: "${WORK:?WORK is required}"
: "${BENCH:?BENCH is required}"
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"

devkit=$LORELEI_DEVKIT
qemu=$QEMU
src=$LIBSODIUM_SOURCE
work=$WORK
bench=$BENCH
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/dump" "$work/results"
cmake -E copy_directory "$src" "$work/source"

if grep -RInE --include='*.c' --include='*.h' \
    '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' "$work/source/src/libsodium" \
    > "$work/dump/setjmp-audit.txt"
then
    echo "libsodium production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_configure=(--disable-static --enable-shared)
(
    cd "$work/native"
    CC=clang-20 "$work/source/configure" "${common_configure[@]}" \
        > "$work/results/native-configure.log" 2>&1
    bear --output compile_commands.json -- make -j"$jobs" \
        > "$work/results/native-build.log" 2>&1
    make check > "$work/results/native-check.log" 2>&1
)

(
    cd "$work/guest"
    CC="$devkit/bin/x86_64-linux-gnu-clang" \
        CFLAGS="--sysroot=$devkit/x86_64/sysroot -O2" \
        LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
        "$work/source/configure" --host=x86_64-linux-gnu "${common_configure[@]}" \
        > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" > "$work/results/guest-build.log" 2>&1
)

tests=$(make -s -C "$work/guest/test/default" \
    --eval='print-tests:;@echo $(TESTS)' print-tests)
make -C "$work/guest/test/default" -j"$jobs" $tests \
    > "$work/results/guest-test-build.log" 2>&1

host_lib="$work/native/src/libsodium/.libs/libsodium.so.26.2.0"
guest_lib_dir="$work/guest/src/libsodium/.libs"
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" \
        && $7 != "UND" && $7 != "ABS" { print }' \
    "$work/dump/host-symbols.txt" > "$work/dump/host-data-tls.txt"
file "$host_lib" > "$work/dump/file.txt"
: > "$work/dump/guest-undefined.txt"
for test_name in $tests; do
    test_bin="$work/guest/test/default/.libs/$test_name"
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
sed -i '/^sodium_allocarray$/d; /^sodium_free$/d; /^sodium_malloc$/d; /^sodium_memzero$/d; /^sodium_misuse$/d; /^sodium_mprotect_noaccess$/d; /^sodium_mprotect_readonly$/d; /^sodium_mprotect_readwrite$/d; /^sodium_set_misuse_handler$/d' \
    "$work/dump/functions.txt"
printf '[Function]\n' > "$work/dump/Symbols.conf"
cat "$work/dump/functions.txt" >> "$work/dump/Symbols.conf"

"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
    -p "$work/native" -o "$work/dump/Desc.dump.h"
"$tlc_wrapper" "$devkit/bin/LoreMakeThunk.py" \
    --name sodium -o "$work/thunk" --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" --desc "$bench/Desc.h" \
    --manifest-host "$bench/Manifest_host.cpp" \
    --manifest-guest "$bench/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -I"$work/source/src/libsodium/include" \
    -I"$work/source/src/libsodium/include/sodium" \
    -I"$work/native/src/libsodium/include" \
    -I"$work/native/src/libsodium/include/sodium"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$tlc_wrapper" "$devkit/bin/LoreMakeThunk.py" \
    --name errno-shim -o "$work/thunk-errno-shim" \
    --lib "$host_libc" --soname errno-shim.so \
    --symbols "$bench/ErrnoSymbols.conf" --desc "$bench/ErrnoDesc.h" \
    --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE
ln -sf "$host_libc" "$work/thunk-errno-shim/liberrno-shim.so"

run_lane() {
    local lane=$1
    local start end
    start=$(date +%s%N)
    QEMU="$qemu" LORELEI_DEVKIT="$devkit" LORE_AE_HECATE=1 \
        HOST_LIB_DIR="$work/native/src/libsodium/.libs" THUNK_DIR="$work/thunk" \
        ERRNO_SHIM_DIR="$work/thunk-errno-shim" \
        make -C "$work/guest/test/default" check-TESTS \
        LOG_COMPILER="$QEMU_WRAPPER" \
        > "$work/results/$lane-check.log" 2>&1
    end=$(date +%s%N)
    sed -n '/^# TOTAL:/,/^# ERROR:/p' "$work/results/$lane-check.log" \
        > "$work/results/$lane.normalized"
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
}

sed -n '/^# TOTAL:/,/^# ERROR:/p' "$work/results/native-check.log" \
    > "$work/results/native.normalized"
run_lane hecate
cmp "$work/results/native.normalized" "$work/results/hecate.normalized"
sha256sum "$work/results/native.normalized" "$work/results/hecate.normalized" \
    > "$work/results/output.sha256"
cp "$work/thunk/.gen/sodium/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
test_count=$(wc -w <<< "$tests")
printf '{\n  "status": "pass",\n  "release": "1.0.20",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": %s,\n  "test_scope": "complete configured upstream make check"\n}\n' \
    "93a7d0d41fe2e32409b5d00386946f491750b7de" "$function_count" "$test_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
