#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
tarball=${LIBPSL_TARBALL:-"$root/../ae-libs/libpsl-0.21.5.tar.gz"}
work=${WORK:-"$root/build/ae-libpsl"}
bench=$(cd "$(dirname "$0")" && pwd)
libc_shim="$bench/libc-shim"
libc_shim_include="$bench/include"
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_sha256=1dcc9ceae8b128f3c0b3f654decd0e1e891afc6ff81098f227ef260449dae208

actual_sha256=$(sha256sum "$tarball" | cut -d ' ' -f1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "libpsl tarball must be the official 0.21.5 release" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/dump" "$work/results"
tar -xf "$tarball" --strip-components=1 -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/src" > "$work/dump/setjmp-audit.txt"
then
    echo "libpsl production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_configure=(--disable-static --enable-shared --disable-runtime --enable-builtin)
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
    CFLAGS="--sysroot=$devkit/x86_64/sysroot" \
    LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
        "$work/source/configure" --host=x86_64-linux-gnu \
        "${common_configure[@]}" > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" > "$work/results/guest-build.log" 2>&1
    make check TESTS= > "$work/results/guest-check-build.log" 2>&1
)

host_lib="$work/native/src/.libs/libpsl.so.5.3.5"
guest_lib_dir="$work/guest/src/.libs"
test_names=(test-is-public test-is-public-all test-is-cookie-domain-acceptable
    test-is-public-builtin test-registrable-domain)
guest_bins=()
for test_name in "${test_names[@]}"; do
    guest_bins+=("$work/guest/tests/$test_name")
done

readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" \
        && $7 != "UND" && $7 != "ABS" { print }' \
    "$work/dump/host-symbols.txt" > "$work/dump/host-data-tls.txt"
file "$host_lib" "${guest_bins[@]}" > "$work/dump/file.txt"
: > "$work/dump/guest-undefined.txt"
for binary in "${guest_bins[@]}"; do
    "$nm" -D --undefined-only --just-symbol-name "$binary" \
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

cp "$bench/Desc.h" "$work/dump/Desc.cpp"
bear --output "$work/dump/compile_commands.json" -- \
    clang++ -fsyntax-only -std=gnu++20 -I"$work/source/include" "$work/dump/Desc.cpp"
"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" -p "$work/dump" -o "$work/dump/Desc.dump.h"

"$devkit/bin/LoreMakeThunk.py" \
    --name psl -o "$work/thunk" --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" --desc "$bench/Desc.h" \
    --manifest-guest "$bench/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -I"$work/source/include" -I"$libc_shim_include"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name c-shim -o "$work/thunk-libc-shim" --lib "$host_libc" \
    --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" \
    --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" \
    --manifest-guest "$libc_shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -D_GNU_SOURCE -I"$libc_shim_include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

run_lane() {
    local lane=$1
    local start end
    rm -f "$work/guest/tests"/*.log "$work/guest/tests"/*.trs
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (
            cd "$work/guest/tests"
            QEMU="$qemu" DEVKIT="$devkit" GUEST_LIB_DIR="$guest_lib_dir" \
                make check LOG_COMPILER="$work/qemu-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    else
        (
            cd "$work/guest/tests"
            QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
            HOST_LIB_DIR="$work/native/src/.libs" THUNK_DIR="$work/thunk" \
            LIBC_SHIM_DIR="$work/thunk-libc-shim" GUEST_LIB_DIR="$guest_lib_dir" \
                make check LOG_COMPILER="$work/qemu-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    fi
    end=$(date +%s%N)
    cp "$work/guest/tests/test-suite.log" "$work/results/$lane-test-suite.log"
    grep -E '^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):' \
        "$work/results/$lane-test-suite.log" > "$work/results/$lane.normalized"
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
}

run_lane hecate
cp "$work/thunk/.gen/psl/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "release": "0.21.5",\n  "archive_sha256": "%s",\n  "functions": %s,\n  "tests": 5,\n  "adaptation": "TLC plus libc-shim"\n}\n' \
    "$actual_sha256" "$function_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
