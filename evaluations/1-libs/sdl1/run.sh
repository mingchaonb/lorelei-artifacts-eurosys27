#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
port_dir=$overlay_dir/ports/sdl1
triplet=arm64-linux-ae
install_only=false
if [[ ${1:-} == --install-only ]]; then
    install_only=true
    shift
fi
if [[ $# != 1 ]]; then
    echo "Usage: $0 [--install-only] /path/to/lorelei-devkit" >&2
    exit 2
fi

devkit=$(realpath "$1")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=${LORELEI_EVALUATION_WORK_DIR:-$repo_root/.work/evaluations/sdl1}
work_dir=$(realpath -m "$work_dir")
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/results/$run_id

[[ -x $vcpkg ]] || { echo "Missing repository vcpkg: $vcpkg" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/LoreHLR bin/x86_64-linux-gnu-clang x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
if ! $install_only; then
    [[ -x $qemu ]] || { echo "Missing patched QEMU: $qemu" >&2; exit 2; }
    for path in lib/libLoreQEMUThreadHook.so lib/libLoreHostHLRExtension.so x86_64/lib/libLoreGuestHLRExtension.so; do
        [[ -e $devkit/$path ]] || { echo "Missing runtime entry: $devkit/$path" >&2; exit 2; }
    done
fi

if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
if [[ -e $work_dir ]]; then
    cmake -E remove_directory "$work_dir"
fi
mkdir -p "$work_dir" "$run_dir"/logs "$run_dir"/generated
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
prefix=$work_dir/installed/hecate/$triplet
thunk=$work_dir/thunks/hecate

echo "[build] SDL 1.2 compatibility ABI and HLR source closure"
"$vcpkg" install "sdl1[hlr]:$triplet" \
    --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
    --x-install-root="$work_dir/installed/hecate" \
    --x-buildtrees-root="$work_dir/vcpkg/hecate/buildtrees" \
    --x-packages-root="$work_dir/vcpkg/hecate/packages" \
    --downloads-root="$work_dir/vcpkg/downloads" --triplet="$triplet" \
    >"$run_dir/logs/vcpkg.log" 2>&1

echo "[thunk] OpenArena SDL 1.2 ABI surface"
host_library=$(find "$prefix/lib" -maxdepth 1 -type f -name 'libSDL-1.2.so.*' | head -1)
"$devkit/bin/LoreMakeThunk.py" --name SDL --out "$thunk" --lib "$host_library" \
    --symbols "$port_dir/lorelei/Symbols.conf" --desc "$port_dir/lorelei/Desc.h" \
    --manifest-host "$port_dir/lorelei/Manifest_host.cpp" \
    --manifest-guest "$port_dir/lorelei/Manifest_guest.cpp" \
    --gtl-alias libSDL-1.2.so --gtl-alias libSDL-1.2.so.0 \
    --htl-alias libSDL-1.2_HTL.so --gtl-arg=-ldl --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- \
    -I"$prefix/include" -I"$prefix/include/SDL" >"$run_dir/logs/thunk.log" 2>&1

cp "$prefix/share/sdl1/hlr-audit/HLRStat.json" "$run_dir/generated/HLRStat.json"
cp "$thunk/.gen/SDL/ThunkStat.json" "$run_dir/generated/ThunkStat.json"
cp "$port_dir/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"
cp "$port_dir/patches/post-hlr.patch" "$run_dir/generated/post-hlr.patch"

if $install_only; then
    status=installed
    test_status=null
else
    echo "[test] video surface, audio callback and guest dynamic loading"
    test_binary=$work_dir/TestSDL1.x86_64
    "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" \
        -I"$prefix/include" -I"$prefix/include/SDL" "$recipe_dir/tests/TestSDL1.c" \
        -L"$thunk/x86_64" -Wl,-rpath,"$thunk/x86_64" -l:libSDL.so -lm \
        -o "$test_binary" >"$run_dir/logs/compile-test.log" 2>&1
    set +e
    env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        LORELEI_THUNK_DATABASE="$prefix/share/sdl1/ThunkDB.json" \
        LORELEI_THUNKS_CONFIG_VARIABLES="SDL1_PREFIX=$prefix;SDL1_THUNK=$thunk" \
        LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
        LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$devkit/lib:$thunk:$prefix/lib" \
        "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
        -E SDL_VIDEODRIVER=dummy -E SDL_AUDIODRIVER=dummy \
        -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
        -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64" "$test_binary" \
        >"$run_dir/logs/hecate.log" 2>&1
    test_status=$?
    set -e
    [[ $test_status == 0 ]] || status=failed
    status=${status:-passed}
fi

python3 - "$run_dir/summary.json" "$status" "$test_status" "$prefix" "$thunk" <<'PY'
import json
import pathlib
import sys

output, status, test_status, prefix, thunk = sys.argv[1:]
data = {
    "schema_version": 1,
    "package": "sdl1",
    "release": "1.2.68",
    "implementation": "sdl12-compat",
    "status": status,
    "hecate_test_exit": None if test_status == "null" else int(test_status),
    "host_prefix": str(pathlib.Path(prefix).resolve()),
    "thunk": str(pathlib.Path(thunk).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

echo "Status: $status"
echo "Evidence: $run_dir"
[[ $status != failed ]]
