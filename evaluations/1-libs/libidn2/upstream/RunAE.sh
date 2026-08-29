#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
tarball=${LIBIDN2_TARBALL:-"$root/../ae-libs/libidn2-2.3.8.tar.gz"}
work=${WORK:-"$root/build/ae-libidn2"}
bench=$(cd "$(dirname "$0")" && pwd)
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_sha256=f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a

actual_sha256=$(sha256sum "$tarball" | cut -d ' ' -f1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "libidn2 tarball must be the official 2.3.8 release" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/dump" "$work/results"
tar -xf "$tarball" --strip-components=1 -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
cp "$bench/CLIWrapper.sh" "$work/idn2-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh" "$work/idn2-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/lib" > "$work/dump/setjmp-audit.txt"
then
    echo "libidn2 production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_configure=(--with-included-libunistring --disable-doc --disable-nls --disable-gcc-warnings)
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
        --enable-cross-guesses=risky "${common_configure[@]}" \
        > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" > "$work/results/guest-build.log" 2>&1
    make -j"$jobs" check TESTS= > "$work/results/guest-check-build.log" 2>&1
)

host_lib="$work/native/lib/.libs/libidn2.so.0.4.0"
guest_bins=(
    "$work/guest/tests/test-version"
    "$work/guest/tests/test-strerror"
    "$work/guest/tests/test-locale"
    "$work/guest/tests/test-tounicode"
    "$work/guest/tests/test-punycode"
    "$work/guest/tests/test-compat-punycode"
    "$work/guest/tests/test-IdnaTest-inc"
    "$work/guest/tests/test-IdnaTest-txt"
    "$work/guest/tests/test-lookup"
    "$work/guest/tests/test-register"
    "$work/guest/tests/test-glibc"
    "$work/guest/src/.libs/idn2"
    "$work/guest/fuzz/libidn2_to_ascii_8z_fuzzer"
    "$work/guest/fuzz/libidn2_to_unicode_8z8z_fuzzer"
    "$work/guest/fuzz/libidn2_register_fuzzer"
)

readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
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
    clang++ -fsyntax-only -std=gnu++20 \
    -I"$work/native/lib" -I"$work/source/lib" "$work/dump/Desc.cpp"
"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" \
    -p "$work/dump" \
    -o "$work/dump/Desc.dump.h"

"$devkit/bin/LoreMakeThunk.py" \
    --name idn2 \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -I"$work/native/lib" \
    -I"$work/source/lib"

clang-20 -shared -fPIC "$bench/HostLocaleShim.c" \
    -o "$work/libLoreHostLocaleShim.so" -ldl

run_lane() {
    local lane=$1
    local start end
    rm -f "$work/guest/fuzz"/*.log "$work/guest/fuzz"/*.trs
    rm -f "$work/guest/tests"/*.log "$work/guest/tests"/*.trs
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (
            cd "$work/guest"
            QEMU="$qemu" DEVKIT="$devkit" \
            GUEST_LIB_DIR="$work/guest/lib/.libs" \
            IDN2="$work/idn2-wrapper.sh" \
            IDN2_GUEST="$work/guest/src/.libs/idn2" \
                make check LOG_COMPILER="$work/qemu-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    else
        (
            cd "$work/guest"
            LC_ALL=C.UTF-8 \
            LD_PRELOAD="$work/libLoreHostLocaleShim.so" \
            QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
            HOST_LIB_DIR="$work/native/lib/.libs" \
            THUNK_DIR="$work/thunk" \
            GUEST_LIB_DIR="$work/guest/lib/.libs" \
            IDN2="$work/idn2-wrapper.sh" \
            IDN2_GUEST="$work/guest/src/.libs/idn2" \
                make check LOG_COMPILER="$work/qemu-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    fi
    end=$(date +%s%N)
    cp "$work/guest/fuzz/test-suite.log" "$work/results/$lane-fuzz-suite.log"
    cp "$work/guest/tests/test-suite.log" "$work/results/$lane-tests-suite.log"
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
    grep -E '^# (TOTAL|PASS|SKIP|XFAIL|FAIL|XPASS|ERROR):' \
        "$work/results/$lane-fuzz-suite.log" "$work/results/$lane-tests-suite.log" \
        | sed "s#$work/results/$lane-##" > "$work/results/$lane.normalized"
}

run_lane hecate

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_sha256": "%s",\n  "functions": %s,\n  "tests": 15,\n  "adaptation": "TLC plus host locale shim"\n}\n' \
    "$actual_sha256" "$function_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
