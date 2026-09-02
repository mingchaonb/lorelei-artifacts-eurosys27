#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
source "$repo_root/evaluations/common/host-architecture.sh"
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
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/$AE_TOOL_TRIPLET/tools/qemu-ae/qemu-x86_64}")
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/results/$run_id
work_dir=$repo_root/.work/evaluations/vulkan-loader
installed=$work_dir/installed/$AE_HOST_TRIPLET
vcpkg=$repo_root/vcpkg/vcpkg
overlay=$repo_root/vcpkg-overlay

if ! $install_only; then
    [[ -x $qemu ]] || { echo "Missing QEMU" >&2; exit 2; }
fi
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
mkdir -p "$work_dir" "$run_dir"/{logs/native,logs/hecate,generated}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

export LORELEI_DEVKIT=$devkit
"$vcpkg" install "vulkan-loader:$AE_HOST_TRIPLET" \
    --editable \
    --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" \
    --downloads-root="$repo_root/vcpkg/downloads" \
    --x-install-root="$work_dir/installed" --x-buildtrees-root="$work_dir/buildtrees" \
    --x-packages-root="$work_dir/packages"

if $install_only; then
    echo "Installed vulkan-loader at $installed"
    exit 0
fi

dpkg-query -W -f='${Package} ${Version}\n' libvulkan1 libvulkan-dev \
    | tee "$run_dir/generated/system-packages.txt"
readelf -n /usr/lib/aarch64-linux-gnu/libvulkan.so.1 > "$run_dir/generated/libvulkan-notes.txt"
"$installed/tools/vulkan-loader/test-vulkan-native" \
    > >(tee "$run_dir/logs/native/vulkan.log") 2>&1
env LORELEI_THUNK_DATABASE="$installed/share/vulkan-loader/ThunkDB.json" \
    LORELEI_THUNKS_CONFIG_VARIABLES="VULKAN_PREFIX=$installed" \
    LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    LD_PRELOAD="$devkit/lib/libLoreHostRT.so:$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$installed/share/vulkan-loader/thunk" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$installed/share/vulkan-loader/thunk/x86_64" \
    "$installed/tools/vulkan-loader/test-vulkan-hecate" \
    > >(tee "$run_dir/logs/hecate/vulkan.log") 2>&1
cp "$installed/share/vulkan-loader/thunk/.gen/vulkan/ThunkStat.json" \
    "$run_dir/generated/Vulkan-ThunkStat.json"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schema_version": 2,
    "package": "vulkan-loader",
    "status": "pass",
    "tests_run": True,
    "native": {"tests_passed": 1},
    "hecate": {"tests_passed": 1},
}, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
