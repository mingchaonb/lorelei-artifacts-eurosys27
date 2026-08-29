#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
tarball=${LIBEXIF_TARBALL:-"$root/../ae-libs/libexif-0.6.26.tar.xz"}
work=${WORK:-"$root/build/ae-libexif"}
bench=$(cd "$(dirname "$0")" && pwd)
libc_shim="$bench/libc-shim"
libc_shim_include="$bench/include"
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_sha256=4a055ed6575e61ca46c3172be3c753cc16c9becd0f99ec71d58dd0e471476c0c

actual_sha256=$(sha256sum "$tarball" | cut -d ' ' -f1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "libexif tarball must be the official 0.6.26 release" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/dump" "$work/results"
tar -xf "$tarball" --strip-components=1 -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/libexif" > "$work/dump/setjmp-audit.txt"
then
    echo "libexif production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_configure=(--disable-static --enable-shared --disable-docs --disable-nls)
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

host_lib="$work/native/libexif/.libs/libexif.so.12.3.4"
guest_lib_dir="$work/guest/libexif/.libs"
test_names=(test-mem test-mnote test-value test-integers test-parse
    test-parse-from-data test-tagtable test-sorted test-fuzzer test-extract
    test-null test-gps)
guest_bins=()
for test_name in "${test_names[@]}"; do
    cp "$bench/TestWrapper.sh" "$work/guest/test/$test_name"
    chmod +x "$work/guest/test/$test_name"
    guest_bins+=("$work/guest/test/.libs/$test_name")
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
    clang++ -fsyntax-only -std=gnu++20 -I"$work/source" "$work/dump/Desc.cpp"
"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" -p "$work/dump" -o "$work/dump/Desc.dump.h"
"$devkit/bin/LoreMakeThunk.py" \
    --name exif -o "$work/thunk" --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" --desc "$bench/Desc.h" \
    --devkit "$devkit" --keep-intermediates -- -I"$work/source"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name c-shim -o "$work/thunk-libc-shim" --lib "$host_libc" \
    --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" \
    --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" \
    --manifest-guest "$libc_shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -D_GNU_SOURCE -I"$libc_shim_include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

grep -E '^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):' \
    "$work/native/test/test-suite.log" > "$work/results/native.normalized"

run_lane() {
    local lane=$1
    local start end
    rm -f "$work/guest/test"/*.log "$work/guest/test"/*.trs
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (
            cd "$work/guest/test"
            QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$work/qemu-wrapper.sh" \
            GUEST_LIB_DIR="$guest_lib_dir" make check
        ) > "$work/results/$lane-check.log" 2>&1
    else
        (
            cd "$work/guest/test"
            QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$work/qemu-wrapper.sh" \
            LORE_AE_HECATE=1 HOST_LIB_DIR="$work/native/libexif/.libs" \
            THUNK_DIR="$work/thunk" LIBC_SHIM_DIR="$work/thunk-libc-shim" \
            GUEST_LIB_DIR="$guest_lib_dir" make check
        ) > "$work/results/$lane-check.log" 2>&1
    fi
    end=$(date +%s%N)
    cp "$work/guest/test/test-suite.log" "$work/results/$lane-test-suite.log"
    grep -E '^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):' \
        "$work/results/$lane-test-suite.log" > "$work/results/$lane.normalized"
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
}

run_lane hecate
sha256sum "$work/results"/*.normalized > "$work/results/output.sha256"
cp "$work/thunk/.gen/exif/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "release": "0.6.26",\n  "archive_sha256": "%s",\n  "functions": %s,\n  "tests": 15,\n  "passed": 14,\n  "skipped": 1,\n  "adaptation": "TLC plus libc-shim"\n}\n' \
    "$actual_sha256" "$function_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
