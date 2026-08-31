#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
install_only=false
while (($#)); do
    case $1 in
        --install-only) install_only=true ;;
        --verbose) ;; # This runner already streams vcpkg output.
        -h|--help) echo "Usage: $0 [--install-only] [--verbose]"; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/results/$run_id
work_dir=$repo_root/.work/evaluations/glvnd
installed=$work_dir/installed/arm64-linux-ae
vcpkg=$repo_root/vcpkg/vcpkg
overlay=$repo_root/vcpkg-overlay

if ! $install_only; then
    [[ -x $qemu ]] || { echo "Missing QEMU: $qemu" >&2; exit 2; }
    display=${DISPLAY:-}
    xauthority=${XAUTHORITY:-}
    if [[ -n ${GUI_ENV:-} ]]; then
        [[ -f $GUI_ENV ]] || { echo "GUI environment file not found: $GUI_ENV" >&2; exit 2; }
        display=$(sed -n 's/^DISPLAY=//p' "$GUI_ENV" | tail -1)
        xauthority=$(sed -n 's/^XAUTHORITY=//p' "$GUI_ENV" | tail -1)
    fi
    [[ -n $display && -n $xauthority ]] || {
        echo "Set DISPLAY and XAUTHORITY, or provide both through GUI_ENV." >&2
        exit 2
    }
fi
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
mkdir -p "$work_dir" "$run_dir"/{logs/native,logs/hecate,generated}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

export LORELEI_DEVKIT=$devkit
"$vcpkg" install glvnd:arm64-linux-ae \
    --editable \
    --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" \
    --downloads-root="$repo_root/vcpkg/downloads" \
    --x-install-root="$work_dir/installed" --x-buildtrees-root="$work_dir/buildtrees" \
    --x-packages-root="$work_dir/packages"

if $install_only; then
    echo "Installed glvnd at $installed"
    exit 0
fi

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
