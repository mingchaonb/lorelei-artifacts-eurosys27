#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
port_dir=$repo_root/vcpkg-overlay/ports/libsamplerate
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
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
vcpkg=$repo_root/vcpkg/vcpkg
work=$repo_root/.work/evaluations/libsamplerate
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
[[ -x $devkit/bin/LoreMakeThunk.py ]] || { echo "Invalid Lorelei devkit: $devkit" >&2; exit 2; }
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to use unmarked work directory: $work" >&2
    exit 2
fi
mkdir -p "$work" "$run_dir"/{generated,logs}
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

invocation=(env "LORELEI_DEVKIT=$devkit" "$recipe_dir/run.sh")
if $reference; then invocation+=(--reference); fi
if $install_only; then invocation+=(--install-only); fi
if $verbose; then invocation+=(--verbose); fi
printf '%q ' "${invocation[@]}" >"$run_dir/invocation.txt"
printf '\n' >>"$run_dir/invocation.txt"
find "$port_dir" -type f -print0 | sort -z | xargs -0 sha256sum >"$run_dir/generated/port-inputs.sha256"
sha256sum "$recipe_dir/tests/Test.c" "$recipe_dir/run.sh" \
    "$repo_root/evaluations/1-libs/.common/audio-signal-upstream.sh" \
    "$repo_root/evaluations/1-libs/.common/audio-signal-ctest.py" >"$run_dir/generated/evaluation-inputs.sha256"

run_logged() {
    local log=$1 status
    shift
    printf '  $'
    printf ' %q' "$@"
    printf '\n'
    if ! $verbose; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

{
    date -u --iso-8601=seconds
    uname -a
    cat /etc/os-release
    lscpu
    free -h
    uptime
    "$vcpkg" version
} >"$run_dir/environment.txt" 2>&1
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local lane=$1 triplet=$2
    run_logged "$run_dir/logs/vcpkg-$lane.log" "$vcpkg" install "libsamplerate:$triplet"         --overlay-ports="$repo_root/vcpkg-overlay/ports"         --overlay-triplets="$repo_root/vcpkg-overlay/triplets"         --x-install-root="$work/installed/$lane"         --x-buildtrees-root="$work/vcpkg/$lane/buildtrees"         --x-packages-root="$work/vcpkg/$lane/packages"         --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet" --binarysource=clear
}
install_lane host arm64-linux-ae
install_lane guest x64-linux-ae
host_prefix=$work/installed/host/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
find "$host_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec file {} + >"$run_dir/generated/host-files.txt"
find "$guest_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec file {} + >"$run_dir/generated/guest-files.txt"
find "$host_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec readelf -d {} \; >"$run_dir/generated/host-dynamic.txt"
find "$guest_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec readelf -d {} \; >"$run_dir/generated/guest-dynamic.txt"
find "$host_prefix/share" -type f -name copyright -print -exec sha256sum {} \; >"$run_dir/generated/licenses.txt"

IFS=';' read -r -a target_specs <<< 'samplerate|libsamplerate.so.*|Symbols.conf|libsamplerate.so,libsamplerate.so.0'
for spec in "${target_specs[@]}"; do
    IFS='|' read -r thunk_name library_pattern symbols aliases <<< "$spec"
    host_library=$(find "$host_prefix/lib" -maxdepth 1 -type f -name "$library_pattern" ! -type l | sort | head -1)
    [[ -n $host_library ]] || { echo "Missing host library for $thunk_name" >&2; exit 1; }
    alias_args=()
    IFS=',' read -r -a alias_list <<< "$aliases"
    for alias in "${alias_list[@]}"; do alias_args+=(--gtl-alias "$alias"); done
    run_logged "$run_dir/logs/thunk-$thunk_name.log" "$devkit/bin/LoreMakeThunk.py"         --name "$thunk_name" --out "$work/thunks/$thunk_name" --lib "$host_library"         --symbols "$port_dir/lorelei/$symbols" --desc "$port_dir/lorelei/Desc.h"         "${alias_args[@]}" --devkit "$devkit" --keep-intermediates -- -I"$host_prefix/include"
    cp "$work/thunks/$thunk_name/.gen/$thunk_name/ThunkStat.json" "$run_dir/generated/$thunk_name-ThunkStat.json"
done

native_status=-1
hecate_status=-1
if $install_only; then
    tests_run=false
    status=installed
else
    qemu=$("$repo_root/evaluations/1-libs/.common/audio-signal-upstream.sh" --resolve-qemu "$devkit" "$repo_root")
    mkdir -p "$work/tests/native" "$work/tests/guest" "$run_dir/logs/native" "$run_dir/logs/hecate"
    link_args=(-lsamplerate -lm)
    native_search=(-L"$host_prefix/lib" -Wl,-rpath,"$host_prefix/lib")
    guest_search=()
    host_runtime_paths=("$devkit/lib" "$host_prefix/lib")
    guest_runtime_paths=("$devkit/x86_64/lib")
    for spec in "${target_specs[@]}"; do
        IFS='|' read -r thunk_name _ _ _ <<< "$spec"
        guest_search+=(-L"$work/thunks/$thunk_name/x86_64" -Wl,-rpath,"$work/thunks/$thunk_name/x86_64")
        host_runtime_paths+=("$work/thunks/$thunk_name")
        guest_runtime_paths+=("$work/thunks/$thunk_name/x86_64")
    done
    run_logged "$run_dir/logs/test-native-build.log" cc -I"$host_prefix/include"         "$recipe_dir/tests/Test.c" "${native_search[@]}" "${link_args[@]}" -o "$work/tests/native/test"
    run_logged "$run_dir/logs/test-guest-build.log" "$devkit/bin/x86_64-linux-gnu-clang"         --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include"         "$recipe_dir/tests/Test.c" "${guest_search[@]}" "${link_args[@]}" -o "$work/tests/guest/test"
    host_runtime=$(IFS=:; echo "${host_runtime_paths[*]}")
    guest_runtime=$(IFS=:; echo "${guest_runtime_paths[*]}")
    set +e
    env LD_LIBRARY_PATH="$host_prefix/lib" "$work/tests/native/test" >"$run_dir/logs/native/workload.log" 2>&1
    native_status=$?
    env LD_LIBRARY_PATH="$host_runtime" "$qemu" -L "$devkit/x86_64/sysroot"         -E LD_BIND_NOW=1 -E LD_LIBRARY_PATH="$guest_runtime"         "$work/tests/guest/test" >"$run_dir/logs/hecate/workload.log" 2>&1
    hecate_status=$?
    set -e
    printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"
    printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"
    cmp "$run_dir/logs/native/workload.log" "$run_dir/logs/hecate/workload.log"
    [[ $native_status == 0 && $hecate_status == 0 ]]
    tests_run=true
    status=pass
    "$repo_root/evaluations/1-libs/.common/audio-signal-upstream.sh" \
        "libsamplerate" "$repo_root" "$work" "$run_dir" "$devkit" "$qemu" \
        "$host_prefix" "$guest_prefix" "$host_runtime" "$guest_runtime" "$verbose"
fi


python3 - "$run_dir/meta.json" "$run_dir/summary.json" "$run_id" "$result_kind" "$install_only" "$tests_run" "$status" "$native_status" "$hecate_status" <<'PY'
import datetime
import json
import pathlib
import sys

meta_path, summary_path, run_id, result_kind, install_only, tests_run, status, native_status, hecate_status = sys.argv[1:]
meta = {
    "schema_version": 2,
    "experiment_id": run_id,
    "package": "libsamplerate",
    "release": "0.2.2",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mechanism": "TLC Only",
}
summary = {
    "schema_version": 2,
    "package": "libsamplerate",
    "version": "0.2.2",
    "status": status,
    "mode": "install-only" if install_only == "true" else "test",
    "tests_run": tests_run == "true",
    "native": {"exit_status": None if native_status == "-1" else int(native_status)},
    "hecate": {"exit_status": None if hecate_status == "-1" else int(hecate_status)},
    "pure_qemu_run": False,
}
pathlib.Path(meta_path).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
pathlib.Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
echo "Build and thunk evidence: $run_dir"
if ! $install_only; then echo "ALL TESTS PASSED: libsamplerate native + Hecate, pure QEMU not run"; fi
