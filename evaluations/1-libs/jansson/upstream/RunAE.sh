#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
bench=$(cd "$(dirname "$0")" && pwd)
libc_shim="$bench/libc-shim"
libc_shim_include="$bench/include"
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
src=${JANSSON_SOURCE:-"$root/../ae-libs/jansson"}
work=${WORK:-"$root/build/ae-jansson"}
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_commit=dbb5fb3636e155fccfce4cd215de752779bd6971

actual_commit=$(git -C "$src" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "Jansson source must be v2.15.1 at $expected_commit" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/host" "$work/guest" "$work/dump" "$work/results"
git -C "$src" archive "$expected_commit" | tar -x -C "$work/source"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$work/source/src" > "$work/dump/setjmp-audit.txt"; then
    echo "Jansson production source uses a forbidden non-local jump" >&2
    exit 1
fi

common_cmake=(
    -G Ninja
    -DJANSSON_BUILD_SHARED_LIBS=ON
    -DJANSSON_WITHOUT_TESTS=OFF
    -DJANSSON_TEST_WITH_VALGRIND=OFF
    -DJANSSON_EXAMPLES=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

CC=clang-20 cmake -S "$work/source" -B "$work/host" "${common_cmake[@]}"
cmake --build "$work/host" -j"$jobs"
(cd "$work/host" && ctest --output-on-failure -j1 \
    > "$work/results/native-check.log" 2>&1)

CC="$devkit/bin/x86_64-linux-gnu-clang" \
    cmake -S "$work/source" -B "$work/guest" "${common_cmake[@]}" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
    -DCMAKE_SYSROOT="$devkit/x86_64/sysroot" \
    -DCMAKE_CROSSCOMPILING_EMULATOR="$work/qemu-wrapper.sh"
cmake --build "$work/guest" -j"$jobs" \
    > "$work/results/guest-build.log" 2>&1

# Jansson uses the legacy add_test signature, for which CMake does not prepend
# CMAKE_CROSSCOMPILING_EMULATOR. Patch only the generated test file so every
# registered upstream test runs through the selected QEMU binary.
sed -i \
    "s#\"$work/guest/bin/#\"$work/qemu-wrapper.sh\" \"$work/guest/bin/#" \
    "$work/guest/CTestTestfile.cmake"

host_lib=$(readlink -f "$work/host/lib/libjansson.so")
guest_lib=$(readlink -f "$work/guest/lib/libjansson.so")
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
file "$host_lib" "$guest_lib" > "$work/dump/file.txt"

mapfile -t guest_bins < <(find "$work/guest/bin" -maxdepth 1 -type f -perm -111 | sort)
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
    --name jansson \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --manifest-guest "$bench/Manifest_guest.cpp" \
    --devkit "$devkit" \
    --keep-intermediates \
    --gtl-arg="-Wl,--undefined-version" \
    --gtl-arg="-Wl,--version-script=$work/host/jansson.sym" \
    -- \
    -I"$work/source/src" \
    -I"$work/host/include" \
    -I"$libc_shim_include"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name c-shim \
    -o "$work/thunk-libc-shim" \
    --lib "$host_libc" \
    --soname libc-shim.so \
    --symbols "$libc_shim/Symbols.conf" \
    --desc "$libc_shim/Desc.h" \
    --manifest-host "$libc_shim/Manifest_host.cpp" \
    --manifest-guest "$libc_shim/Manifest_guest.cpp" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -D_GNU_SOURCE \
    -I"$libc_shim_include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

test_count=$(cd "$work/guest" && ctest -N | sed -n 's/^Total Tests: //p')
ctest_args=(--output-on-failure -j1)
if [[ -n "${CTEST_REGEX:-}" ]]; then
    ctest_args+=(-R "$CTEST_REGEX")
fi
for lane in hecate; do
    output="$work/results/$lane.log"
    start=$(date +%s%N)
    if [[ "$lane" == qemu ]]; then
        (cd "$work/guest" && \
            QEMU="$qemu" DEVKIT="$devkit" GUEST_LIB_DIR="$work/guest/lib" \
            ctest "${ctest_args[@]}") > "$output" 2>&1
    else
        (cd "$work/guest" && \
            QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
            HOST_LIB_DIR="$work/host/lib" THUNK_DIR="$work/thunk" \
            LIBC_SHIM_DIR="$work/thunk-libc-shim" \
            ctest "${ctest_args[@]}") > "$output" 2>&1
    fi
    end=$(date +%s%N)
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
    sed -E \
        -e 's/[0-9]+\.[0-9]+ sec/<TIME> sec/g' \
        -e 's/[0-9]+\.[0-9]+ sec\*proc/<TIME> sec*proc/g' \
        -e 's/Total Test time \(real\) = +[0-9]+\.[0-9]+ sec/Total Test time (real) = <TIME> sec/' \
        "$output" > "$work/results/$lane.normalized"
done

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": %s\n}\n' \
    "$actual_commit" "$function_count" "$test_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
cat "$work/results/hecate.time"
