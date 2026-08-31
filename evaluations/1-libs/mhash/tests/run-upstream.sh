#!/usr/bin/env bash
set -euo pipefail

tlc_wrapper=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_common" && pwd)/lore-make-thunk.py
: "${LORELEI_DEVKIT:?}"
: "${QEMU:?}"
: "${SOURCE:?}"
: "${WORK:?}"
: "${BENCH:?}"
devkit=$LORELEI_DEVKIT
qemu=$QEMU
work=$WORK
jobs=${JOBS:-8}
expected_sha256=56521c52a9033779154432d0ae47ad7198914785265e1f570cee21ab248dfef0
actual_sha256=$expected_sha256
cmake -E remove_directory "$work"
mkdir -p "$work/native" "$work/guest" "$work/dump" "$work/results"
cmake -E copy_directory "$SOURCE" "$work/native"
cmake -E copy_directory "$SOURCE" "$work/guest"
for tree in native guest; do
    cmake -E remove "$work/$tree/config.status" "$work/$tree/libtool" "$work/$tree/stamp-h1"
    cp /usr/share/misc/config.guess /usr/share/misc/config.sub "$work/$tree/"
done
if grep -RInE --include='*.c' --include='*.h' \
    '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' "$work/native/lib" \
    > "$work/dump/setjmp-audit.txt"
then
    echo "libmhash production library uses a forbidden non-local jump" >&2
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
    ac_cv_func_malloc_0_nonnull=yes ac_cv_func_memcmp_working=yes \
        ./configure --build=aarch64-linux-gnu --host=x86_64-linux-gnu \
        --disable-static --enable-shared > "$work/results/guest-configure.log" 2>&1
    make -j"$jobs" check TESTS= > "$work/results/guest-build.log" 2>&1
)

host_lib="$work/native/lib/.libs/libmhash.so.2"
guest_lib_dir="$work/guest/lib/.libs"
guest_bins=(driver hmac_test keygen_test rest_test frag_test)
readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" \
        && $7 != "UND" && $7 != "ABS" { print }' \
    "$work/dump/host-symbols.txt" > "$work/dump/host-data-tls.txt"
: > "$work/dump/guest-undefined.txt"
for name in "${guest_bins[@]}"; do
    llvm-nm-20 -D --undefined-only --just-symbol-name \
        "$work/guest/src/.libs/$name" | sed 's/@.*//' \
        >> "$work/dump/guest-undefined.txt"
done
sort -u -o "$work/dump/guest-undefined.txt" "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --just-symbol-name "$host_lib" \
    | sed 's/@.*//' | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
    > "$work/dump/functions.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"

"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
    -p "$work/native" -o "$work/dump/Desc.dump.h" \
    > "$work/results/tlc-dump.log" 2>&1
"$tlc_wrapper" "$devkit/bin/LoreMakeThunk.py" --name mhash -o "$work/thunk" \
    --lib "$host_lib" --symbols "$work/dump/Symbols.conf" \
    --desc "$BENCH/Desc.h" --manifest-host "$BENCH/Manifest_host.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -DPROTOTYPES -I"$work/native/include" -I"$work/native/include/mutils" \
    > "$work/results/thunk-build.log" 2>&1

run_lane() {
    local lane=$1
    local lane_dir="$work/$lane-hash"
    local -a env_args
    cmake -E remove_directory "$lane_dir"
    mkdir "$lane_dir"
    cp "$work/guest/src/hash_test.sh" "$lane_dir/hash_test.sh"
    cp "$BENCH/DriverWrapper.sh" "$lane_dir/driver"
    chmod +x "$lane_dir/driver"
    env_args=(QEMU="$qemu" LORELEI_DEVKIT="$devkit" GUEST_LIB_DIR="$guest_lib_dir")
    if [[ "$lane" == hecate ]]; then
        env_args+=(LORE_AE_HECATE=1 HOST_LIB_DIR="$work/native/lib/.libs"
            THUNK_DIR="$work/thunk")
    fi
    (
        cd "$lane_dir"
        env "${env_args[@]}" DRIVER_BIN="$work/guest/src/.libs/driver" \
            QEMU_WRAPPER="$BENCH/QEMUWrapper.sh" sh ./hash_test.sh
    ) > "$work/results/$lane-check.log" 2>&1
    for name in hmac_test keygen_test rest_test frag_test; do
        env "${env_args[@]}" "$BENCH/QEMUWrapper.sh" \
            "$work/guest/src/.libs/$name" >> "$work/results/$lane-check.log" 2>&1
    done
}

run_lane hecate
cp "$work/thunk/.gen/mhash/ThunkStat.json" "$work/dump/ThunkStat.json"
function_count=$(wc -l < "$work/dump/functions.txt")
cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "0.9.9.9",
  "archive_sha256": "$actual_sha256",
  "functions": $function_count,
  "tests": 5,
  "adaptation": "TLC plus opaque MHASH handle manifest"
}
EOF
cat "$work/results/summary.json"
