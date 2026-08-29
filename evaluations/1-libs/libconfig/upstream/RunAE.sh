#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
bench=$(cd "$(dirname "$0")" && pwd)
libc_shim="$bench/libc-shim"
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
source_repo=${LIBCONFIG_SOURCE:-"$root/../ae-libs/libconfig"}
work=${WORK:-"$root/build/ae-libconfig"}
jobs=${JOBS:-8}
expected_commit=a42cb47c1526a4f2ed025fcbb2289863375bc898

actual_commit=$(git -C "$source_repo" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "libconfig source must be the pinned v1.8.2 revision" >&2
    exit 1
fi
cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" \
    "$work/results" "$work/dump"
git -C "$source_repo" archive HEAD | tar -x -C "$work/source"

common=(-DBUILD_SHARED_LIBS=ON -DBUILD_TESTS=ON -DBUILD_EXAMPLES=OFF
    -DBUILD_FUZZERS=OFF -DBUILD_CXX=OFF)
cmake -S "$work/source" -B "$work/native" -G Ninja "${common[@]}" \
    -DCMAKE_C_COMPILER=clang-20 -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON > "$work/results/native-configure.log" 2>&1
cmake --build "$work/native" -j"$jobs" > "$work/results/native-build.log" 2>&1
(
    cd "$work/source/tests"
    "$work/native/out/libconfig_tests" > "$work/results/native-tests.log" 2>&1
)

if grep -RInE --include='*.c' --include='*.h' \
    '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' "$work/source/lib" \
    > "$work/dump/setjmp-audit.txt"
then
    echo "libconfig production source uses a forbidden non-local jump" >&2
    exit 1
fi

cmake -S "$work/source" -B "$work/guest" -G Ninja "${common[@]}" \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_C_COMPILER="$devkit/bin/x86_64-linux-gnu-clang" \
    -DCMAKE_SYSROOT="$devkit/x86_64/sysroot" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo > "$work/results/guest-configure.log" 2>&1
cmake --build "$work/guest" -j"$jobs" > "$work/results/guest-build.log" 2>&1
guest_bin="$work/guest/out/libconfig_tests"
host_lib="$work/native/out/libconfig.so.15.0.0"
LC_ALL=C readelf -d "$guest_bin" > "$work/dump/guest-dynamic.txt"
grep -q 'Shared library: \[libconfig.so.15\]' "$work/dump/guest-dynamic.txt"
llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_bin" \
    | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --just-symbol-name "$host_lib" \
    | sed 's/@.*//' | sort -u > "$work/dump/host-defined.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-defined.txt" \
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
"$devkit/bin/LoreMakeThunk.py" --name config -o "$work/thunk" \
    --lib "$host_lib" --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- -I"$work/source/lib" \
    > "$work/results/thunk-build.log" 2>&1

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" --name c-shim -o "$work/thunk-libc-shim" \
    --lib "$host_libc" --soname libc-shim.so \
    --symbols "$libc_shim/Symbols.conf" --desc "$libc_shim/Desc.h" \
    --manifest-host "$libc_shim/Manifest_host.cpp" \
    --manifest-guest "$libc_shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -D_GNU_SOURCE -I"$bench/include" \
    > "$work/results/libc-shim-build.log" 2>&1
ln -s "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

(
    cd "$work/source/tests"
    env LD_LIBRARY_PATH="$devkit/lib:$work/native/out:$work/thunk:$work/thunk-libc-shim" \
        "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
        -E "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" \
        "$guest_bin" > "$work/results/hecate-tests.log" 2>&1
)
grep -q '^16 tests; 16 passed, 0 failed$' "$work/results/hecate-tests.log"
cp "$work/thunk/.gen/config/ThunkStat.json" "$work/dump/ThunkStat.json"

function_count=$(wc -l < "$work/dump/functions.txt")
data_count=$(wc -l < "$work/dump/data-used.txt")
cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "1.8.2",
  "commit": "$actual_commit",
  "functions": $function_count,
  "guest_data_references": $data_count,
  "tests": 16,
  "adaptation": "TLC without callback replacement plus libc-shim"
}
EOF
cat "$work/results/summary.json"
