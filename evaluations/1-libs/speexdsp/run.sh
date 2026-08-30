#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
port_dir=$repo_root/vcpkg-overlay/ports/speexdsp
vcpkg=$repo_root/vcpkg/vcpkg
work=$repo_root/.work/evaluations/speexdsp

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
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

# Validate every tool before creating an evidence directory.
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
for path in bin/LoreMakeThunk.py x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
qemu=
if ! $install_only; then
    qemu=$("$repo_root/evaluations/1-libs/.common/audio-signal-upstream.sh" --resolve-qemu "$devkit" "$repo_root")
fi

# Keep vcpkg packages between runs and replace only generated thunk and runtime files.
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to use unmarked work directory: $work" >&2
    exit 2
fi
for scratch in "$work/thunk" "$work/runtime"; do
    if [[ -e $scratch ]]; then cmake -E remove_directory "$scratch"; fi
done
mkdir -p "$work" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$work/.lorelei-evaluations-workspace"
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

# Record provenance and the exact repository inputs used for this run.
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
    if ! $install_only; then sha256sum "$qemu"; fi
} >"$run_dir/environment.txt" 2>&1
find "$port_dir" -type f -print0 | sort -z | xargs -0 sha256sum >"$run_dir/generated/port-inputs.sha256"
sha256sum "$recipe_dir/run.sh" >"$run_dir/generated/evaluation-inputs.sha256"
python3 - "$run_dir/meta.json" "$run_id" "$result_kind" "$devkit" "$qemu" "$install_only" <<'PY'
import datetime, json, pathlib, sys
output, run_id, result_kind, devkit, qemu, install_only = sys.argv[1:]
data = {
    "schema_version": 2,
    "experiment_id": run_id,
    "package": "speexdsp",
    "release": "1.2.1",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mode": "install-only" if install_only == "true" else "test",
    "mechanism": "TLC Only",
    "devkit": str(pathlib.Path(devkit).resolve()),
    "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

stage "Measure per-library configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "$port_dir/lorelei/Desc.h" "$port_dir/lorelei/Symbols.conf"

# Install the same pinned port for native AArch64 and x86_64 guest execution.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local lane=$1 triplet=$2
    run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "speexdsp:$triplet" \
        --overlay-ports="$repo_root/vcpkg-overlay/ports" \
        --overlay-triplets="$repo_root/vcpkg-overlay/triplets" \
        --x-install-root="$work/installed/$lane" \
        --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" \
        --x-packages-root="$work/vcpkg/$lane/packages" \
        --downloads-root="$work/vcpkg/downloads" --triplet="$triplet" --binarysource=clear
}

stage "Install the SpeexDSP DSO and all five upstream test programs"
install_lane host arm64-linux-ae
install_lane guest x64-linux-ae
host_prefix=$work/installed/host/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
host_tests=$host_prefix/tools/speexdsp/upstream-tests/bin
guest_tests=$guest_prefix/tools/speexdsp/upstream-tests/bin
for name in testdenoise testecho testjitter testresample testresample2; do
    [[ -x $host_tests/$name ]] || { echo "Missing native upstream test: $name" >&2; exit 1; }
    [[ -x $guest_tests/$name ]] || { echo "Missing guest upstream test: $name" >&2; exit 1; }
done

# Generate the sole TLC thunk directly from the installed host package.
stage "Generate the SpeexDSP TLC thunk"
host_library=$(find "$host_prefix/lib" -maxdepth 1 -type f -name 'libspeexdsp.so.*' | sort | head -1)
[[ -n $host_library ]] || { echo "Installed SpeexDSP DSO not found" >&2; exit 1; }
run_logged "$run_dir/logs/preparation/thunk.log" "$devkit/bin/LoreMakeThunk.py" \
    --name speexdsp --out "$work/thunk" --lib "$host_library" \
    --symbols "$port_dir/lorelei/Symbols.conf" --desc "$port_dir/lorelei/Desc.h" \
    --gtl-alias libspeexdsp.so --gtl-alias libspeexdsp.so.1 \
    --devkit "$devkit" --keep-intermediates -- -I"$host_prefix/include"
cp "$work/thunk/.gen/speexdsp/ThunkStat.json" "$run_dir/generated/ThunkStat.json"
find "$host_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec file {} + >"$run_dir/generated/host-files.txt"
find "$guest_prefix/lib" -maxdepth 1 -type f -name '*.so*' -exec file {} + >"$run_dir/generated/guest-files.txt"

if $install_only; then
    python3 - "$run_dir/summary.json" "$host_prefix" "$guest_prefix" "$work/thunk" <<'PY'
import json, pathlib, sys
output, host, guest, thunk = sys.argv[1:]
data = {"schema_version": 2, "package": "speexdsp", "status": "installed", "mode": "install-only", "tests_run": False, "installed": {"native": host, "guest": guest, "thunk": thunk}}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Installation evidence: $run_dir"
    exit 0
fi

# Generate fixed signed 16-bit PCM once. Both lanes consume these exact bytes.
stage "Generate deterministic PCM fixtures"
mkdir -p "$work/runtime"/{inputs,native,hecate}
python3 - "$work/runtime/inputs" <<'PY'
import array, math, pathlib, sys
root = pathlib.Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
count = 1024
mic = array.array("h", (int(9000 * math.sin(i * 0.071)) for i in range(count)))
ref = array.array("h", (int(6000 * math.cos(i * 0.043)) for i in range(count)))
mic.tofile((root / "mic.pcm").open("wb"))
ref.tofile((root / "reference.pcm").open("wb"))
PY
sha256sum "$work/runtime/inputs/"*.pcm >"$run_dir/generated/fixtures.sha256"

run_lane() {
    local lane=$1 tests=$2 runtime=$3
    shift 3
    local log_dir=$run_dir/logs/$lane output_dir=$work/runtime/$lane name status
    local -a launcher=("$@")
    : >"$log_dir/status.tsv"
    for name in testdenoise testecho testjitter testresample testresample2; do
        set +e
        case $name in
            testdenoise)
                "${launcher[@]}" "$tests/$name" <"$work/runtime/inputs/mic.pcm" \
                    >"$output_dir/$name.bin" 2>"$log_dir/$name.log"
                ;;
            testecho)
                "${launcher[@]}" "$tests/$name" "$work/runtime/inputs/mic.pcm" \
                    "$work/runtime/inputs/reference.pcm" "$output_dir/$name.bin" \
                    >"$log_dir/$name.stdout.log" 2>"$log_dir/$name.log"
                ;;
            testjitter)
                "${launcher[@]}" "$tests/$name" >"$output_dir/$name.txt" 2>"$log_dir/$name.log"
                ;;
            testresample)
                "${launcher[@]}" "$tests/$name" <"$work/runtime/inputs/mic.pcm" \
                    >"$output_dir/$name.bin" 2>"$log_dir/$name.log"
                ;;
            testresample2)
                "${launcher[@]}" "$tests/$name" >"$output_dir/$name.bin" 2>"$log_dir/$name.log"
                ;;
        esac
        status=$?
        set -e
        printf '%s\t%s\n' "$name" "$status" >>"$log_dir/status.tsv"
        printf '  -> %s exit %s\n' "$name" "$status"
    done
    find "$output_dir" -type f -maxdepth 1 -print0 | sort -z | xargs -0 sha256sum >"$log_dir/outputs.sha256"
    find "$output_dir" -type f -maxdepth 1 -printf '%f\t%s\n' | sort >"$log_dir/output-sizes.tsv"
}

stage "Run all five upstream programs natively"
run_lane native "$host_tests" "$work/runtime/native" env LD_LIBRARY_PATH="$host_prefix/lib"

stage "Run all five upstream programs through Hecate, TLC Only"
run_lane hecate "$guest_tests" "$work/runtime/hecate" \
    env LD_LIBRARY_PATH="$devkit/lib:$work/thunk:$host_prefix/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$work/thunk/x86_64"

# Classify raw statuses and output invariants into the machine-readable verdict.
stage "Summarize native and Hecate results"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir" --runtime "$work/runtime"
echo "ALL TESTS PASSED: speexdsp native=5 Hecate=5 pure_qemu=false"
echo "Evidence: $run_dir"
