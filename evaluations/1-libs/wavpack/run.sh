#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
port_dir=$overlay_dir/ports/wavpack
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
            echo "Usage: $0 [--reference] [--install-only] [--verbose] /path/to/lorelei-devkit"
            echo "Set QEMU=/path/to/qemu-x86_64 only for a development devkit."
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) positional+=("$1") ;;
    esac
    shift
done
[[ ${#positional[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }

devkit=$(realpath "${positional[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=$repo_root/.work/evaluations/wavpack
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
# Preserve ABI-matching vcpkg installs across runs. Reset only generated thunks.
if [[ -e $work_dir/thunks ]]; then cmake -E remove_directory "$work_dir/thunks"; fi
mkdir -p "$work_dir" "$run_dir"/{generated/targets/wavpack,logs/preparation,logs/native,logs/hecate}
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
invocation=("$0")
if $reference; then invocation+=(--reference); fi
if $install_only; then invocation+=(--install-only); fi
if $verbose; then invocation+=(--verbose); fi
invocation+=("$devkit")
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
    "package": "wavpack",
    "release": "5.9.0",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mode": "install-only" if install_only == "true" else "test",
    "mechanism": "TLC + HLR",
    "workload": "wvtest --exhaustive --short --no-extras",
    "devkit": str(pathlib.Path(devkit).resolve()),
    "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

# Count the complete repository-owned TLC API and callback configuration.
stage "Measure per-library configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "$port_dir/lorelei/Desc.h" "$port_dir/lorelei/Symbols.conf" "$port_dir/lorelei/Manifest_host.cpp"

# Build isolated native, guest, and HLR host packages from one pinned overlay.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local name=$1 triplet=$2 package=wavpack
    if [[ $name == hecate ]]; then package='wavpack[hlr]'; fi
    run_logged "$run_dir/logs/preparation/vcpkg-$name.log" "$vcpkg" install "$package:$triplet" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$work_dir/vcpkg/downloads" --triplet="$triplet"
}

stage "Build pinned WavPack packages and upstream wvtest through the repository overlay"
if ! $install_only; then install_lane native "$triplet_native"; install_lane guest "$triplet_guest"; fi
install_lane hecate "$triplet_native"

# Export the exact filtered database and statistics, then create the runnable thunk.
hecate_prefix=$work_dir/installed/hecate/$triplet_native
cp -a "$hecate_prefix/share/wavpack/hlr-audit/." "$run_dir/generated/targets/wavpack/"
cp "$port_dir/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

stage "Generate the Hecate WavPack thunk"
host_library=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name 'libwavpack.so.*' | head -1)
thunk=$work_dir/thunks/hecate
run_logged "$run_dir/logs/preparation/thunk-hecate.log" "$devkit/bin/LoreMakeThunk.py" \
    --name wavpack --out "$thunk" --lib "$host_library" \
    --symbols "$port_dir/lorelei/Symbols.conf" --desc "$port_dir/lorelei/Desc.h" \
    --manifest-host "$port_dir/lorelei/Manifest_host.cpp" \
    --gtl-alias libwavpack.so --gtl-alias libwavpack.so.1 --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include/wavpack"

# Install-only records the completed package and thunk without running wvtest.
if $install_only; then
    python3 - "$run_dir/summary.json" "$hecate_prefix" "$thunk" <<'PY'
import json, pathlib, sys
output, host, thunk = sys.argv[1:]
data = {"schema_version": 2, "package": "wavpack", "status": "installed", "mode": "install-only", "tests_run": False, "installed": {"hecate_host": host, "thunk": thunk}}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Hecate host library: $hecate_prefix"
    echo "WavPack thunk: $thunk"
    echo "Installation record: $run_dir"
    exit 0
fi

# Use upstream's same wvtest executable source in the native and guest lanes.
native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
native_wvtest=$native_prefix/tools/wavpack/upstream-tests/bin/wvtest
guest_wvtest=$guest_prefix/tools/wavpack/upstream-tests/bin/wvtest
[[ -x $native_wvtest ]] || { echo "Native wvtest not found: $native_wvtest" >&2; exit 2; }
[[ -x $guest_wvtest ]] || { echo "Guest wvtest not found: $guest_wvtest" >&2; exit 2; }

# Run the native control and preserve all 164 result lines plus its exit status.
stage "Run native wvtest --exhaustive --short --no-extras"
set +e
LD_LIBRARY_PATH="$native_prefix/lib" "$native_wvtest" --exhaustive --short --no-extras 2>&1 | tee "$run_dir/logs/native/wvtest.log"
native_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"

# Run the x86_64 upstream exerciser through Hecate with thread reentry enabled.
stage "Run Hecate wvtest --exhaustive --short --no-extras, TLC + HLR"
set +e
env LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$thunk:$hecate_prefix/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64" \
    "$guest_wvtest" --exhaustive --short --no-extras 2>&1 | tee "$run_dir/logs/hecate/wvtest.log"
hecate_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"

# Recompute the verdict from raw wvtest logs and the committed HLR audit.
stage "Summarize native and Hecate results"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
