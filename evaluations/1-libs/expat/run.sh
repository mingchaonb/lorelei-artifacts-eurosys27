#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
port_dir=$overlay_dir/ports/expat
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

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
qemu=$(realpath -m "${QEMU:-$repo_root/../qemu-ae/build/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=$repo_root/.work/evaluations/expat
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

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

[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
# Preserve ABI-matching vcpkg installs across runs. Reset only derived test and thunk files.
for scratch_path in "$work_dir/tests" "$work_dir/thunks"; do
    if [[ -e $scratch_path ]]; then cmake -E remove_directory "$scratch_path"; fi
done
mkdir -p "$work_dir" "$run_dir"/{generated/targets/expat,logs/preparation,logs/native,logs/hecate}
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
    "package": "expat",
    "release": "2.8.2",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mode": "install-only" if install_only == "true" else "test",
    "mechanism": "TLC + HLR",
    "devkit": str(pathlib.Path(devkit).resolve()),
    "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

stage "Measure per-library configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "$port_dir/lorelei/Desc.h"

export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local name=$1 triplet=$2 package=expat
    if [[ $name == hecate ]]; then package='expat[hlr]'; fi
    run_logged "$run_dir/logs/preparation/vcpkg-$name.log" "$vcpkg" install "$package:$triplet" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}

stage "Build pinned Expat packages through the repository overlay"
if ! $install_only; then install_lane native "$triplet_native"; install_lane guest "$triplet_guest"; fi
install_lane hecate "$triplet_native"

hecate_prefix=$work_dir/installed/hecate/$triplet_native
cp -a "$hecate_prefix/share/expat/hlr-audit/." "$run_dir/generated/targets/expat/"
cp "$port_dir/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

stage "Generate the Hecate Expat thunk"
host_library=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name 'libexpat.so.*' | head -1)
thunk=$work_dir/thunks/hecate
run_logged "$run_dir/logs/preparation/thunk-hecate.log" "$devkit/bin/LoreMakeThunk.py" \
    --name expat --out "$thunk" --lib "$host_library" \
    --symbols "$port_dir/lorelei/Symbols.conf" --desc "$port_dir/lorelei/Desc.h" \
    --gtl-alias libexpat.so --gtl-alias libexpat.so.1 --no-callback-replace \
    --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"

if $install_only; then
    python3 - "$run_dir/summary.json" "$hecate_prefix" "$thunk" <<'PY'
import json, pathlib, sys
output, host, thunk = sys.argv[1:]
data = {"schema_version": 2, "package": "expat", "status": "installed", "mode": "install-only", "tests_run": False, "installed": {"hecate_host": host, "thunk": thunk}}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Hecate host library: $hecate_prefix"
    echo "Expat thunk: $thunk"
    echo "Installation record: $run_dir"
    exit 0
fi

native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
mkdir -p "$work_dir/tests/native" "$work_dir/tests/guest"
stage "Build the directed parser workload"
run_logged "$run_dir/logs/preparation/test-native.log" cc \
    -I"$native_prefix/include" "$recipe_dir/tests/TestCallbacks.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lexpat -o "$work_dir/tests/native/test-callbacks"
run_logged "$run_dir/logs/preparation/test-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include" "$recipe_dir/tests/TestCallbacks.c" \
    -L"$thunk/x86_64" -Wl,-rpath,"$thunk/x86_64" -l:libexpat.so -o "$work_dir/tests/guest/test-callbacks"

stage "Run the native workload"
set +e
LD_LIBRARY_PATH="$native_prefix/lib" "$work_dir/tests/native/test-callbacks" 2>&1 | tee "$run_dir/logs/native/callbacks.log"
native_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"

stage "Run the Hecate workload, TLC + HLR"
set +e
env LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$thunk:$hecate_prefix/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64" \
    "$work_dir/tests/guest/test-callbacks" 2>&1 | tee "$run_dir/logs/hecate/callbacks.log"
hecate_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"

stage "Summarize native and Hecate results"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
