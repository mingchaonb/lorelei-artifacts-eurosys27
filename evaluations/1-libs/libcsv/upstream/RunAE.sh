#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
source_repo=${LIBCSV_SOURCE:-"$root/../ae-libs/libcsv"}
work=${WORK:-"$root/build/ae-libcsv"}
bench=$(cd "$(dirname "$0")" && pwd)
jobs=${JOBS:-8}
expected_commit=b1d5212831842ee5869d99bc208a21837e4037d5

actual_commit=$(git -C "$source_repo" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "libcsv source must be the pinned 3.0.3 revision" >&2
    exit 1
fi
cmake -E remove_directory "$work"
mkdir -p "$work/native" "$work/guest" "$work/results" "$work/dump"
git -C "$source_repo" archive HEAD | tar -x -C "$work/native"
git -C "$source_repo" archive HEAD | tar -x -C "$work/guest"

if grep -RInE --include='*.c' --include='*.h' \
    '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/native/libcsv.c" "$work/native/csv.h" \
    > "$work/dump/setjmp-audit.txt"
then
    echo "libcsv production source uses a forbidden non-local jump" >&2
    exit 1
fi

(
    cd "$work/native"
    CC=clang-20 ./configure --build=aarch64-linux-gnu \
        --disable-static --enable-shared > "$work/results/native-configure.log" 2>&1
    bear --output compile_commands.json -- make -j"$jobs" check \
        > "$work/results/native-check.log" 2>&1
)
(
    cd "$work/guest"
    CC="$devkit/bin/x86_64-linux-gnu-clang" \
    CFLAGS="--sysroot=$devkit/x86_64/sysroot" \
    LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
        ./configure --build=aarch64-linux-gnu --host=x86_64-linux-gnu \
        --disable-static --enable-shared > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" check TESTS= > "$work/results/guest-build.log" 2>&1
)

guest_bin="$work/guest/.libs/check_csv"
host_lib="$work/native/.libs/libcsv.so.3.0.3"
LC_ALL=C readelf -d "$guest_bin" > "$work/dump/guest-dynamic.txt"
if ! grep -q 'Shared library: \[libcsv.so.3\]' "$work/dump/guest-dynamic.txt"; then
    echo "guest check_csv is not dynamically linked to libcsv.so.3" >&2
    exit 1
fi
llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_bin" \
    | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --just-symbol-name "$host_lib" \
    | sed 's/@.*//' | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
    > "$work/dump/functions.txt"
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" \
        && $7 != "UND" && $7 != "ABS" { print }' \
    "$work/dump/host-symbols.txt" > "$work/dump/host-data-tls.txt"
comm -12 "$work/dump/guest-undefined.txt" \
    <(awk '{print $8}' "$work/dump/host-data-tls.txt" | sed 's/@.*//' | sort -u) \
    > "$work/dump/data-used.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"

"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
    -p "$work/native" -o "$work/dump/Desc.dump.h" \
    > "$work/results/tlc-dump.log" 2>&1
"$devkit/bin/LoreMakeThunk.py" --name csv -o "$work/thunk" \
    --lib "$host_lib" --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" --manifest-host "$bench/Manifest_host.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -I"$work/native" > "$work/results/thunk-build.log" 2>&1

env LD_LIBRARY_PATH="$devkit/lib:$work/native/.libs:$work/thunk" \
    "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" "$guest_bin" \
    > "$work/results/hecate-direct.log" 2>&1
grep -qx 'All tests passed' "$work/results/hecate-direct.log"
cp "$work/thunk/.gen/csv/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
data_count=$(wc -l < "$work/dump/data-used.txt")
cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "3.0.3",
  "commit": "$actual_commit",
  "functions": $function_count,
  "guest_data_references": $data_count,
  "tests": 1,
  "adaptation": "TLC plus output-initializer manifest"
}
EOF
cat "$work/results/summary.json"
