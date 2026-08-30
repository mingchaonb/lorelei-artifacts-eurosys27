#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
common_dir=$repo_root/evaluations/common
overlay_dir=$repo_root/vcpkg-overlay
mixer_port=$overlay_dir/ports/sdl2-mixer
sdl_port=$overlay_dir/ports/sdl2
triplet_native=arm64-linux-ae
triplet_guest=x64-linux-ae

# Parse the common evaluation modes while keeping the devkit as the only
# positional argument.
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

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=$repo_root/.work/evaluations/sdl2-mixer
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

# Validate tools before allocating an append-only evidence directory.
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

# Replace only this recipe's marked scratch directory. Prior evidence remains.
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
# Preserve ABI-matching vcpkg installs across runs. Reset only derived test and thunk files.
for scratch_path in "$work_dir/tests" "$work_dir/thunks"; do
    if [[ -e $scratch_path ]]; then cmake -E remove_directory "$scratch_path"; fi
done
mkdir -p "$work_dir" "$run_dir"/{generated/targets/SDL2_mixer,generated/dependencies/SDL2,logs/preparation,logs/native,logs/hecate}
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

# Record invocation, machine identity, and relevant tool versions.
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
    "package": "sdl2-mixer",
    "release": "2.8.2",
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

# Count only SDL2_mixer's TLC API configuration. SDL2 is measured separately.
stage "Measure per-library configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "$mixer_port/lorelei/Desc.h" "$mixer_port/lorelei/Symbols.conf"

# Build isolated native, guest, and HLR package graphs from the same overlays.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local name=$1 triplet=$2
    local packages=(sdl2-mixer)
    if [[ $name == hecate ]]; then packages=('sdl2[hlr]' 'sdl2-mixer[hlr]'); fi
    run_logged "$run_dir/logs/preparation/vcpkg-$name.log" "$vcpkg" install "${packages[@]}" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}

stage "Build pinned SDL2 and SDL2_mixer packages through the repository overlay"
if ! $install_only; then install_lane native "$triplet_native"; install_lane guest "$triplet_guest"; fi
install_lane hecate "$triplet_native"

# Preserve the mixer audit and reviewed SDL2 dependency audit in this run.
hecate_prefix=$work_dir/installed/hecate/$triplet_native
cp -a "$hecate_prefix/share/sdl2-mixer/hlr-audit/." "$run_dir/generated/targets/SDL2_mixer/"
cp -a "$hecate_prefix/share/sdl2/hlr-audit/." "$run_dir/generated/dependencies/SDL2/"
cp "$mixer_port/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

# Generate the SDL2 dependency thunk using its manifests and established aliases.
stage "Generate the Hecate SDL2 dependency thunk"
sdl_library=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name 'libSDL2-2.0.so.*' | head -1)
sdl_thunk=$work_dir/thunks/SDL2
run_logged "$run_dir/logs/preparation/thunk-SDL2.log" "$devkit/bin/LoreMakeThunk.py" \
    --name SDL2 --out "$sdl_thunk" --lib "$sdl_library" \
    --symbols "$sdl_port/lorelei/Symbols.conf" --desc "$sdl_port/lorelei/Desc.h" \
    --manifest-host "$sdl_port/lorelei/Manifest_host.cpp" --manifest-guest "$sdl_port/lorelei/Manifest_guest.cpp" \
    --gtl-alias libSDL2-2.0.so --gtl-alias libSDL2-2.0.so.0 --htl-alias libSDL2-2.0_HTL.so \
    --gtl-arg=-ldl --no-callback-replace --devkit "$devkit" --keep-intermediates -- \
    -I"$hecate_prefix/include" -I"$hecate_prefix/include/SDL2" -I"$common_dir/include"

# Generate the mixer thunk independently with callback replacement disabled.
stage "Generate the Hecate SDL2_mixer thunk"
mixer_library=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name 'libSDL2_mixer-2.0.so.*' | head -1)
mixer_thunk=$work_dir/thunks/SDL2_mixer
run_logged "$run_dir/logs/preparation/thunk-SDL2-mixer.log" "$devkit/bin/LoreMakeThunk.py" \
    --name SDL2_mixer --out "$mixer_thunk" --lib "$mixer_library" \
    --symbols "$mixer_port/lorelei/Symbols.conf" --desc "$mixer_port/lorelei/Desc.h" \
    --gtl-alias libSDL2_mixer-2.0.so --gtl-alias libSDL2_mixer-2.0.so.0 --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include" -I"$hecate_prefix/include/SDL2"

# Install-only stops after producing the host packages, audits, and both thunks.
if $install_only; then
    python3 - "$run_dir/summary.json" "$hecate_prefix" "$sdl_thunk" "$mixer_thunk" <<'PY'
import json, pathlib, sys
output, host, sdl, mixer = sys.argv[1:]
data = {"schema_version": 2, "package": "sdl2-mixer", "status": "installed", "mode": "install-only", "tests_run": False, "installed": {"hecate_host": host, "sdl2_thunk": sdl, "sdl2_mixer_thunk": mixer}}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Hecate host packages: $hecate_prefix"
    echo "SDL2 thunk: $sdl_thunk"
    echo "SDL2_mixer thunk: $mixer_thunk"
    echo "Installation record: $run_dir"
    exit 0
fi

# Compile the identical raw-audio effect workload for native and guest lanes.
native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
mkdir -p "$work_dir/tests/native" "$work_dir/tests/guest"
stage "Build the directed mixer callback workload"
run_logged "$run_dir/logs/preparation/test-native.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestEffect.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2_mixer -lSDL2 \
    -o "$work_dir/tests/native/test-effect"
run_logged "$run_dir/logs/preparation/test-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include/SDL2" "$recipe_dir/tests/TestEffect.c" \
    -L"$mixer_thunk/x86_64" -L"$sdl_thunk/x86_64" \
    -Wl,-rpath,"$mixer_thunk/x86_64:$sdl_thunk/x86_64" -l:libSDL2_mixer.so -l:libSDL2.so \
    -o "$work_dir/tests/guest/test-effect"

# Run the native control through SDL's deterministic dummy audio backend.
stage "Run the native workload"
set +e
SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy LD_LIBRARY_PATH="$native_prefix/lib" \
    "$work_dir/tests/native/test-effect" 2>&1 | tee "$run_dir/logs/native/effect.log"
native_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"

# Run the guest through both thunks. The host thread hook makes SDL's native
# audio callback thread enter the guest callback safely.
stage "Run the Hecate workload, TLC + HLR"
set +e
env SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy \
    LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$mixer_thunk:$sdl_thunk:$hecate_prefix/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
    -E SDL_AUDIODRIVER=dummy -E SDL_VIDEODRIVER=dummy \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$mixer_thunk/x86_64:$sdl_thunk/x86_64" \
    "$work_dir/tests/guest/test-effect" 2>&1 | tee "$run_dir/logs/hecate/effect.log"
hecate_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"

# Recompute the verdict only from raw outputs and the saved mixer audit.
stage "Summarize native and Hecate results"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
