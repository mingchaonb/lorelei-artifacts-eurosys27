#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
common_dir=$repo_root/evaluations/common
overlay_dir=$repo_root/vcpkg-overlay
image_port=$overlay_dir/ports/sdl2-image
sdl_port=$overlay_dir/ports/sdl2
triplet_native=arm64-linux-ae
triplet_guest=x64-linux-ae

reference=false
install_only=false
verbose=false
positional=()
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --verbose) verbose=true ;;
        -h|--help)
            echo "Usage: $0 [--reference] [--install-only] [--verbose]"
            echo "Set QEMU=/path/to/qemu-x86_64 only for a development devkit."
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=$repo_root/.work/evaluations/sdl2-image
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

# Validate the tools before allocating a timestamped evidence directory.
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/LoreHLR bin/x86_64-linux-gnu-clang x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
if ! $install_only; then
    for path in lib/libLoreQEMUThreadHook.so lib/libLoreHostHLRExtension.so x86_64/lib/libLoreGuestHLRExtension.so; do
        [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
    done
    [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
fi

# Replace only this recipe's marked scratch directory. Evidence remains append-only.
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
# Preserve ABI-matching vcpkg installs across runs. Reset only derived test and thunk files.
for scratch_path in "$work_dir/tests" "$work_dir/thunks"; do
    if [[ -e $scratch_path ]]; then cmake -E remove_directory "$scratch_path"; fi
done
mkdir -p "$work_dir" "$run_dir"/{generated/targets/SDL2_image,generated/dependencies/SDL2,logs/preparation,logs/native,logs/hecate}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

stage() { printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$1"; }
run_logged() {
    local log=$1 status
    shift
    printf '  $'; printf ' %q' "$@"; printf '\n'
    if ! $verbose; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

# Record the invocation, machine identity, and relevant tool versions.
stage "Record invocation and environment"
invocation=(env "LORELEI_DEVKIT=$devkit" "$recipe_dir/run.sh")
if $reference; then invocation+=(--reference); fi
if $install_only; then invocation+=(--install-only); fi
if $verbose; then invocation+=(--verbose); fi
printf '%q ' "${invocation[@]}" >"$run_dir/invocation.txt"
printf '\n' >>"$run_dir/invocation.txt"
{
    date -u --iso-8601=seconds
    uname -a
    cat /etc/os-release
    lscpu
    free -h
    uptime
    "$vcpkg" version
    "$devkit/bin/LoreHLR" --version
    if ! $install_only; then sha256sum "$qemu"; fi
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$result_kind" "$devkit" "$qemu" "$install_only" <<'PY'
import datetime, json, pathlib, sys
output, run_id, result_kind, devkit, qemu, install_only = sys.argv[1:]
data = {
    "schema_version": 2,
    "experiment_id": run_id,
    "package": "sdl2-image",
    "release": "2.8.12",
    "dependency": {"package": "sdl2", "release": "2.28.5"},
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mode": "install-only" if install_only == "true" else "test",
    "mechanism": "TLC + HLR",
    "devkit": str(pathlib.Path(devkit).resolve()),
    "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

# Count only SDL2_image's repository-owned TLC API configuration. SDL2 effort is
# already measured by the dependency's independent evaluation recipe.
stage "Measure per-library configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "$image_port/lorelei/Desc.h" "$image_port/lorelei/Symbols.conf"

# Build isolated native, guest, and HLR package graphs from the same overlays.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local name=$1 triplet=$2
    local packages=(sdl2-image)
    if [[ $name == hecate ]]; then packages=('sdl2[hlr]' 'sdl2-image[hlr]'); fi
    run_logged "$run_dir/logs/preparation/vcpkg-$name.log" "$vcpkg" install "${packages[@]}" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}

stage "Build pinned SDL2 and SDL2_image packages through the repository overlay"
if ! $install_only; then install_lane native "$triplet_native"; install_lane guest "$triplet_guest"; fi
install_lane hecate "$triplet_native"

# Preserve image audit data and the already-reviewed SDL2 dependency audit.
hecate_prefix=$work_dir/installed/hecate/$triplet_native
cp -a "$hecate_prefix/share/sdl2-image/hlr-audit/." "$run_dir/generated/targets/SDL2_image/"
cp -a "$hecate_prefix/share/sdl2/hlr-audit/." "$run_dir/generated/dependencies/SDL2/"
cp "$image_port/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

# Generate the SDL2 dependency thunk using its existing manifests and aliases.
make_sdl_thunk() {
    local prefix=$1 output=$2 host_library
    host_library=$(find "$prefix/lib" -maxdepth 1 -type f -name 'libSDL2-2.0.so.*' | head -1)
    "$repo_root/evaluations/1-libs/_common/lore-make-thunk.py" "$devkit/bin/LoreMakeThunk.py" --name SDL2 --out "$output" --lib "$host_library" \
        --symbols "$sdl_port/lorelei/Symbols.conf" --desc "$sdl_port/lorelei/Desc.h" \
        --manifest-host "$sdl_port/lorelei/Manifest_host.cpp" --manifest-guest "$sdl_port/lorelei/Manifest_guest.cpp" \
        --gtl-alias libSDL2-2.0.so --gtl-alias libSDL2-2.0.so.0 --htl-alias libSDL2-2.0_HTL.so \
        --gtl-arg=-ldl --no-callback-replace --devkit "$devkit" --keep-intermediates -- \
        -I"$prefix/include" -I"$prefix/include/SDL2" -I"$common_dir/include"
}

stage "Generate the Hecate SDL2 dependency thunk"
sdl_thunk=$work_dir/thunks/SDL2
run_logged "$run_dir/logs/preparation/thunk-SDL2.log" make_sdl_thunk "$hecate_prefix" "$sdl_thunk"

# Generate the image thunk independently so both DSO boundaries remain visible.
stage "Generate the Hecate SDL2_image thunk"
image_library=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name 'libSDL2_image-2.0.so.*' | head -1)
image_thunk=$work_dir/thunks/SDL2_image
run_logged "$run_dir/logs/preparation/thunk-SDL2-image.log" "$repo_root/evaluations/1-libs/_common/lore-make-thunk.py" "$devkit/bin/LoreMakeThunk.py" \
    --name SDL2_image --out "$image_thunk" --lib "$image_library" \
    --symbols "$image_port/lorelei/Symbols.conf" --desc "$image_port/lorelei/Desc.h" \
    --gtl-alias libSDL2_image-2.0.so --gtl-alias libSDL2_image-2.0.so.0 --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include" -I"$hecate_prefix/include/SDL2"

# Install-only records the complete two-DSO Hecate path without running it.
if $install_only; then
    python3 - "$run_dir/summary.json" "$hecate_prefix" "$sdl_thunk" "$image_thunk" <<'PY'
import json, pathlib, sys
output, host, sdl, image = sys.argv[1:]
data = {"schema_version": 2, "package": "sdl2-image", "status": "installed", "mode": "install-only", "tests_run": False, "installed": {"hecate_host": host, "sdl2_thunk": sdl, "sdl2_image_thunk": image}}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Hecate host packages: $hecate_prefix"
    echo "SDL2 thunk: $sdl_thunk"
    echo "SDL2_image thunk: $image_thunk"
    echo "Installation record: $run_dir"
    exit 0
fi

# Compile the identical in-memory PNM and upstream-fixture workload for both
# lanes. The official release's test directory supplies all fixture bytes.
native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
fixture_dir=$native_prefix/tools/sdl2-image/upstream-tests/data
[[ -d $fixture_dir ]] || { echo "SDL2_image upstream fixtures not found" >&2; exit 2; }
mkdir -p "$work_dir/tests/native" "$work_dir/tests/guest"
stage "Build the in-memory and upstream-fixture image workload"
run_logged "$run_dir/logs/preparation/test-native.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestFormats.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2_image -lSDL2 \
    -o "$work_dir/tests/native/test-formats"
run_logged "$run_dir/logs/preparation/test-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include/SDL2" "$recipe_dir/tests/TestFormats.c" \
    -L"$image_thunk/x86_64" -L"$sdl_thunk/x86_64" \
    -Wl,-rpath,"$image_thunk/x86_64:$sdl_thunk/x86_64" -l:libSDL2_image.so -l:libSDL2.so \
    -o "$work_dir/tests/guest/test-formats"

# Run the native control with the same dummy backend environment.
stage "Run the native workload"
set +e
SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy LD_LIBRARY_PATH="$native_prefix/lib" \
    "$work_dir/tests/native/test-formats" "$fixture_dir" 2>&1 | tee "$run_dir/logs/native/image-load.log"
native_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"

# Run the guest through both thunks and both HLR-rewritten host DSOs.
stage "Run the Hecate workload, TLC + HLR"
set +e
env SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy \
    LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$image_thunk:$sdl_thunk:$hecate_prefix/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
    -E SDL_AUDIODRIVER=dummy -E SDL_VIDEODRIVER=dummy \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$image_thunk/x86_64:$sdl_thunk/x86_64" \
    "$work_dir/tests/guest/test-formats" "$fixture_dir" 2>&1 | tee "$run_dir/logs/hecate/image-load.log"
hecate_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"

# Recompute the verdict from raw logs and the image DSO audit.
stage "Summarize native and Hecate results"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
