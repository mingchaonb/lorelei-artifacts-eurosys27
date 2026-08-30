#!/usr/bin/env bash
set -euo pipefail

target_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$target_dir/../../.." && pwd)
rover_root=$(cd "$repo_root/.." && pwd)
devkit=${1:-$rover_root/lorelei-ae/build/install}
blink=${BLINK:-$rover_root/blink-ae/o/rel/blink/blink}
box64=${BOX64:-$rover_root/box64-ae/build-ae/box64}
fex=${FEX:-$rover_root/FEX-ae/build-ae-clang/Bin/FEX}
iterations=${ITERATIONS:-1000}
state=$repo_root/.work/evaluations/hecate-emulators
host_prefix=$repo_root/.work/evaluations/breakdown-test/installed/hecate/arm64-linux-ae
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_dir=$target_dir/results/$run_id
host_dir=$state/host
thunk=$state/thunk

test -x "$blink"
test -x "$box64"
test -x "$fex"
test -x "$devkit/bin/LoreMakeThunk.py"
test -x "$devkit/bin/x86_64-linux-gnu-clang"
test -f "$host_prefix/include/breakdown-test.h"
mkdir -p "$host_dir" "$result_dir/raw"

cc -shared -O2 -fPIC -I"$host_prefix/include" "$target_dir/host.c" \
    -Wl,-soname,libbreakdown_test.so.1 \
    -o "$host_dir/libbreakdown_test.so.1"
ln -sfn libbreakdown_test.so.1 "$host_dir/libbreakdown_test.so"

"$devkit/bin/LoreMakeThunk.py" \
    --name breakdown_test \
    --out "$thunk" \
    --lib "$host_dir/libbreakdown_test.so.1" \
    --symbols "$target_dir/Symbols.conf" \
    --desc "$repo_root/vcpkg-overlay/ports/breakdown-test/lorelei/Desc.h" \
    --gtl-alias libbreakdown_test.so.1 \
    --devkit "$devkit" \
    --keep-intermediates \
    -- -I"$host_prefix/include" \
    >"$result_dir/thunk.log" 2>&1

"$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -O2 \
    -I"$host_prefix/include" "$target_dir/benchmark.c" \
    -L"$thunk/x86_64" -Wl,-rpath,"$thunk/x86_64" \
    -lbreakdown_test -o "$state/benchmark.x86_64"

host_ld="$devkit/lib:$host_dir:$thunk"
guest_ld="$devkit/x86_64/lib:$thunk/x86_64"

env LD_LIBRARY_PATH="$host_ld:$guest_ld" \
    BLINK_OVERLAYS="$devkit/x86_64/sysroot:" \
    "$blink" "$state/benchmark.x86_64" "$iterations" \
    >"$result_dir/raw/blink.stdout" 2>"$result_dir/raw/blink.stderr"

env LD_LIBRARY_PATH="$host_ld" \
    BOX64_LD_LIBRARY_PATH="$guest_ld" \
    BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 \
    "$box64" "$state/benchmark.x86_64" "$iterations" \
    >"$result_dir/raw/box64.stdout" 2>"$result_dir/raw/box64.stderr"

timeout 30s env LD_LIBRARY_PATH="$host_ld" \
    FEX_ROOTFS="$devkit/x86_64/sysroot" \
    FEX_ENV="LD_LIBRARY_PATH=$guest_ld" \
    FEX_OUTPUTLOG=stderr \
    "$fex" "$state/benchmark.x86_64" "$iterations" \
    >"$result_dir/raw/fex.stdout" 2>"$result_dir/raw/fex.stderr"

expected="direct=ok host_address=ok guest_callback=ok iterations=$iterations"
for emulator in blink box64 fex; do
    grep -Fx "$expected" "$result_dir/raw/$emulator.stdout"
done

{
    date -u --iso-8601=seconds
    uname -a
    printf 'iterations=%s\n' "$iterations"
    for repo in blink-ae box64-ae FEX-ae lorelei-ae; do
        printf '%s=' "$repo"
        git -C "$rover_root/$repo" rev-parse HEAD
    done
    printf 'blink=%s\nbox64=%s\nfex=%s\n' "$blink" "$box64" "$fex"
} >"$result_dir/environment.txt"

echo "Evidence: $result_dir"
