#!/usr/bin/env bash

# Shared path discovery and evidence helpers for command-line workloads.
cli_common_init() {
    workload_dir=$1
    cli_root=$(cd "$workload_dir/.." && pwd)
    repo_root=$(cd "$cli_root/../.." && pwd)
    rover_root=$(cd "$repo_root/.." && pwd)
    emulator_tools=$repo_root/vcpkg/installed/arm64-linux/tools
    devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
    qemu=$(realpath -m "${QEMU:-$emulator_tools/qemu-ae/qemu-x86_64}")
    blink=$(realpath -m "${BLINK:-$emulator_tools/blink-ae/blink}")
    box64=$(realpath -m "${BOX64:-$emulator_tools/box64-ae/box64}")
    fex=$(realpath -m "${FEX:-$emulator_tools/fex-ae/FEX}")
    repetitions=${REPETITIONS:-5}
    # Figure 17 omits lanes that take more than 20x the calibrated native
    # workload. Native runs take at least 1.5 seconds, and 100 seconds is the
    # fixed upper bound used to keep the full emulator matrix tractable.
    timeout_seconds=$(python3 -c 'import sys; print(min(100.0, float(sys.argv[1])))' "${TIMEOUT_SECONDS:-100}")
    input_dir=$cli_root/_inputs
    measure_py=$cli_root/_common/measure.py
}

cli_parse_options() {
    reference=false
    install_only=false
    lanes=${LANES:-native,qemu,blink,box64,fex,qemu-hecate,blink-hecate,box64-hecate,fex-hecate}
    while (($#)); do
        case $1 in
            --reference) reference=true ;;
            --install-only) install_only=true ;;
            --lanes) shift; lanes=${1:?--lanes requires a comma-separated value} ;;
            -h|--help) return 64 ;;
            --*) echo "Unknown option: $1" >&2; return 2 ;;
            *) echo "Unexpected positional argument: $1" >&2; return 2 ;;
        esac
        shift
    done
}

cli_begin_result() {
    local workload=$1
    local root=$workload_dir/results
    $reference && root=$workload_dir/reference-results
    run_id=$(date -u +%Y%m%dT%H%M%SZ)
    result_dir=$root/$run_id
    mkdir -p "$result_dir"
    {
        date -u --iso-8601=seconds
        uname -a
        cat /etc/os-release
        lscpu
        uptime
        printf 'workload=%s\nrepetitions=%s\ntimeout_seconds=%s\nlanes=%s\n' \
            "$workload" "$repetitions" "$timeout_seconds" "$lanes"
        printf 'qemu=%s\nblink=%s\nbox64=%s\nfex=%s\n' \
            "$qemu" "$blink" "$box64" "$fex"
        sha256sum "$qemu" "$blink" "$box64" "$fex"
        "$repo_root/vcpkg/vcpkg" list | grep -E \
            '^(qemu-ae|blink-ae|box64-ae|fex-ae):arm64-linux' || true
        for repo in lorelei-ae qemu-ae blink-ae box64-ae FEX-ae eurosys-lorelei-artifacts; do
            if [[ -d $rover_root/$repo/.git ]]; then
                printf '%s=' "$repo"
                git -C "$rover_root/$repo" rev-parse HEAD
            fi
        done
    } >"$result_dir/environment.txt" 2>&1
    cp "$input_dir/manifest.json" "$result_dir/input-manifest.json"
}

cli_has_lane() {
    [[ ,$lanes, == *,$1,* ]]
}

cli_lane_timeout() {
    local lane=$1
    local native_summary=$result_dir/native.json
    if [[ $lane != native && -f $native_summary ]]; then
        python3 - "$native_summary" "$timeout_seconds" <<'PY'
import json
import sys

summary = json.load(open(sys.argv[1]))
hard_limit = float(sys.argv[2])
native_median = summary.get("seconds", {}).get("median")
print(min(hard_limit, 20 * native_median) if native_median else hard_limit)
PY
    else
        printf '%s\n' "$timeout_seconds"
    fi
}

cli_measure() {
    local lane=$1
    local lane_timeout
    shift
    cli_has_lane "$lane" || return 0
    lane_timeout=$(cli_lane_timeout "$lane")
    python3 "$measure_py" --result-dir "$result_dir" --lane "$lane" \
        --repetitions "$repetitions" --timeout "$lane_timeout" -- "$@"
}

cli_measure_stdio() {
    local lane=$1
    local stdin_file=$2
    local lane_timeout
    shift 2
    cli_has_lane "$lane" || return 0
    lane_timeout=$(cli_lane_timeout "$lane")
    python3 "$measure_py" --result-dir "$result_dir" --lane "$lane" \
        --repetitions "$repetitions" --timeout "$lane_timeout" \
        --stdin-file "$stdin_file" --stdout-to-output -- "$@"
}

cli_measure_excludable() {
    local lane=$1
    local reason=$2
    local lane_timeout
    shift 2
    cli_has_lane "$lane" || return 0
    lane_timeout=$(cli_lane_timeout "$lane")
    python3 "$measure_py" --result-dir "$result_dir" --lane "$lane" \
        --repetitions "$repetitions" --timeout "$lane_timeout" \
        --exclude-nonzero --exclusion-reason "$reason" -- "$@"
}

cli_require_executable() {
    [[ -x $1 ]] || { echo "Missing executable: $1" >&2; exit 2; }
}
