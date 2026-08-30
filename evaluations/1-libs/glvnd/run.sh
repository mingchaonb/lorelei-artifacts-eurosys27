#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    echo "Usage: $0"
    exit 0
fi
[[ $# == 0 ]] || { echo "Unexpected positional argument: $1" >&2; exit 2; }
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
qemu=$(realpath "${QEMU:-$repo_root/../qemu-ae/build/qemu-x86_64}")
gui_env=${GUI_ENV:-$HOME/Desktop/spark-gui-env.txt}
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/results/$run_id
work_dir=$repo_root/.work/evaluations/glvnd
installed=$work_dir/installed/arm64-linux-ae
vcpkg=$repo_root/vcpkg/vcpkg
overlay=$repo_root/vcpkg-overlay

[[ -x $qemu && -f $gui_env ]] || { echo "Missing QEMU or GUI environment" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
if [[ -e $work_dir ]]; then cmake -E remove_directory "$work_dir"; fi
mkdir -p "$work_dir" "$run_dir"/{logs/native,logs/hecate,generated}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

display=$(sed -n 's/^DISPLAY=//p' "$gui_env" | tail -1)
xauthority=$(sed -n 's/^XAUTHORITY=//p' "$gui_env" | tail -1)
export LORELEI_DEVKIT=$devkit
"$vcpkg" install glvnd:arm64-linux-ae \
    --editable \
    --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" \
    --downloads-root="$repo_root/vcpkg/downloads" \
    --x-install-root="$work_dir/installed" --x-buildtrees-root="$work_dir/buildtrees" \
    --x-packages-root="$work_dir/packages"

dpkg-query -W -f='${Package} ${Version}\n' libgl1 libglvnd0 libglx0 \
    | tee "$run_dir/generated/system-packages.txt"
readelf -n /usr/lib/aarch64-linux-gnu/libGL.so.1 > "$run_dir/generated/libGL-notes.txt"
readelf -n /usr/lib/aarch64-linux-gnu/libGLX.so.0 > "$run_dir/generated/libGLX-notes.txt"
env DISPLAY="$display" XAUTHORITY="$xauthority" "$installed/tools/glvnd/test-glx-native" \
    > >(tee "$run_dir/logs/native/glx.log") 2>&1
env DISPLAY="$display" XAUTHORITY="$xauthority" "$installed/tools/glvnd/test-glx-direct-native" \
    > >(tee "$run_dir/logs/native/glx-direct.log") 2>&1
env LORELEI_THUNK_DATABASE="$installed/share/glvnd/ThunkDB.json" \
    LORELEI_THUNKS_CONFIG_VARIABLES="GLVND_PREFIX=$installed" \
    LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    DISPLAY="$display" XAUTHORITY="$xauthority" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$installed/share/glvnd/thunk:$installed/share/glvnd/x11-thunk:$installed/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
    -E DISPLAY="$display" -E XAUTHORITY="$xauthority" -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$installed/share/glvnd/thunk/x86_64:$installed/share/glvnd/x11-thunk/x86_64" \
    "$installed/tools/glvnd/test-glx-hecate" > >(tee "$run_dir/logs/hecate/glx.log") 2>&1
env LORELEI_THUNK_DATABASE="$installed/share/glvnd/ThunkDB.json" \
    LORELEI_THUNKS_CONFIG_VARIABLES="GLVND_PREFIX=$installed" \
    LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    DISPLAY="$display" XAUTHORITY="$xauthority" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$installed/share/glvnd/glx-thunk:$installed/share/glvnd/thunk:$installed/share/glvnd/x11-thunk:$installed/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
    -E DISPLAY="$display" -E XAUTHORITY="$xauthority" -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$installed/share/glvnd/glx-thunk/x86_64:$installed/share/glvnd/thunk/x86_64:$installed/share/glvnd/x11-thunk/x86_64" \
    "$installed/tools/glvnd/test-glx-direct-hecate" \
    > >(tee "$run_dir/logs/hecate/glx-direct.log") 2>&1
cp "$installed/share/glvnd/thunk/.gen/GL/ThunkStat.json" "$run_dir/generated/GL-ThunkStat.json"
cp "$installed/share/glvnd/glx-thunk/.gen/GLX/ThunkStat.json" "$run_dir/generated/GLX-ThunkStat.json"
cp "$installed/share/glvnd/x11-thunk/.gen/X11/ThunkStat.json" "$run_dir/generated/X11-ThunkStat.json"
echo "Evidence: $run_dir"
