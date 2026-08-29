#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
tarball=${LIBICONV_TARBALL:-"$root/../ae-libs/libiconv-1.18.tar.gz"}
work=${WORK:-"$root/build/ae-libiconv"}
bench=$(cd "$(dirname "$0")" && pwd)
errno_shim="$bench"
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_sha256=3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8

actual_sha256=$(sha256sum "$tarball" | cut -d ' ' -f1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "libiconv tarball must be the official 1.18 release" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/dump" "$work/results"
tar -xf "$tarball" --strip-components=1 -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
cp "$bench/CompilerWrapper.sh" "$work/compiler-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh" "$work/compiler-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/lib" > "$work/dump/setjmp-audit.txt"
then
    echo "libiconv production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_configure=(--disable-static --enable-shared --disable-nls)
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
        "$work/source/configure" --host=x86_64-linux-gnu \
        "${common_configure[@]}" > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" > "$work/results/guest-build.log" 2>&1
    make -C tests table-from table-to is-native test-shiftseq test-to-wchar \
        test-bom-state test-discard > "$work/results/guest-test-build.log" 2>&1
)

host_lib="$work/native/lib/.libs/libiconv.so.2.7.0"
guest_lib_dir="$work/guest/lib/.libs"
test_programs=(table-from table-to is-native test-shiftseq test-to-wchar
    test-bom-state test-discard)
guest_bins=("$work/guest/src/.libs/iconv_no_i18n")
for program in "${test_programs[@]}"; do
    if [[ "$program" == is-native ]]; then
        mv "$work/guest/tests/$program" "$work/guest/tests/$program.guest"
        guest_bins+=("$work/guest/tests/$program.guest")
    else
        guest_bins+=("$work/guest/tests/.libs/$program")
    fi
    cp "$bench/ProgramWrapper.sh" "$work/guest/tests/$program"
    chmod +x "$work/guest/tests/$program"
done
cp "$bench/ProgramWrapper.sh" "$work/guest/src/iconv_no_i18n"
chmod +x "$work/guest/src/iconv_no_i18n"

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
cat >> "$work/dump/Symbols.conf" <<'EOF'
[Callback]
iconv_unicode_char_hook
iconv_wide_char_hook
iconv_unicode_mb_to_uc_fallback
iconv_unicode_uc_to_mb_fallback
iconv_wchar_mb_to_wc_fallback
iconv_wchar_wc_to_mb_fallback
EOF

cp "$bench/Desc.h" "$work/dump/Desc.cpp"
bear --output "$work/dump/compile_commands.json" -- \
    clang++ -fsyntax-only -std=gnu++20 -I"$work/native/include" "$work/dump/Desc.cpp"
"$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" -p "$work/dump" -o "$work/dump/Desc.dump.h"
"$devkit/bin/LoreMakeThunk.py" \
    --name iconv -o "$work/thunk" --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" --desc "$bench/Desc.h" \
    --manifest-host "$bench/Manifest_host.cpp" \
    --devkit "$devkit" --keep-intermediates -- -I"$work/native/include"

"$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -shared -fPIC "$bench/GuestMetadata.c" \
    -o "$work/libIconvGuestMetadata.so"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name errno-shim -o "$work/thunk-errno-shim" --lib "$host_libc" \
    --soname errno-shim.so --symbols "$errno_shim/ErrnoSymbols.conf" \
    --desc "$errno_shim/ErrnoDesc.h" --devkit "$devkit" \
    --keep-intermediates -- -D_GNU_SOURCE
ln -sf "$host_libc" "$work/thunk-errno-shim/liberrno-shim.so"
clang-20 -shared -fPIC "$bench/HostLocaleShim.c" \
    -o "$work/libLoreHostLocaleShim.so" -ldl

run_lane() {
    local lane=$1
    local start end
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (
            cd "$work/guest/tests"
            QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$work/qemu-wrapper.sh" \
            GUEST_LIB_DIR="$guest_lib_dir" REAL_CC="$devkit/bin/x86_64-linux-gnu-clang" \
            PROGRAM_WRAPPER="$bench/ProgramWrapper.sh" \
                make check CC="$work/compiler-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    else
        (
            cd "$work/guest/tests"
            QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$work/qemu-wrapper.sh" \
            LORE_AE_HECATE=1 HOST_LIB_DIR="$work/native/lib/.libs" \
            THUNK_DIR="$work/thunk" ERRNO_SHIM_DIR="$work/thunk-errno-shim" \
            METADATA_SO="$work/libIconvGuestMetadata.so" GUEST_LIB_DIR="$guest_lib_dir" \
            HOST_LOCALE_SO="$work/libLoreHostLocaleShim.so" \
            REAL_CC="$devkit/bin/x86_64-linux-gnu-clang" \
            PROGRAM_WRAPPER="$bench/ProgramWrapper.sh" \
                make check CC="$work/compiler-wrapper.sh"
        ) > "$work/results/$lane-check.log" 2>&1
    fi
    end=$(date +%s%N)
    printf 'PASS complete make check\n' > "$work/results/$lane.normalized"
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
}

run_lane hecate
cp "$work/thunk/.gen/iconv/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "release": "1.18",\n  "archive_sha256": "%s",\n  "functions": %s,\n  "test_scope": "complete upstream make check",\n  "adaptation": "TLC plus guest metadata and errno shim"\n}\n' \
    "$actual_sha256" "$function_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
