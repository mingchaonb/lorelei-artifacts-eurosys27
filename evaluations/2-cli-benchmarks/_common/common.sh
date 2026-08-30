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
    timeout_seconds=${TIMEOUT_SECONDS:-180}
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

cli_measure() {
    local lane=$1
    shift
    cli_has_lane "$lane" || return 0
    python3 "$measure_py" --result-dir "$result_dir" --lane "$lane" \
        --repetitions "$repetitions" --timeout "$timeout_seconds" -- "$@"
}

cli_measure_stdio() {
    local lane=$1
    local stdin_file=$2
    shift 2
    cli_has_lane "$lane" || return 0
    python3 "$measure_py" --result-dir "$result_dir" --lane "$lane" \
        --repetitions "$repetitions" --timeout "$timeout_seconds" \
        --stdin-file "$stdin_file" --stdout-to-output -- "$@"
}

cli_require_executable() {
    [[ -x $1 ]] || { echo "Missing executable: $1" >&2; exit 2; }
}
