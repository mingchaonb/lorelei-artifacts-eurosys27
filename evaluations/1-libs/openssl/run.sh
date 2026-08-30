#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay=$repo_root/vcpkg-overlay
reference=false
install_only=false
verbose=false
args=()
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --verbose) verbose=true ;;
        -h|--help) echo "Usage: $0 [--reference] [--install-only] [--verbose] /path/to/lorelei-devkit"; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ ${#args[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${args[0]}")
vcpkg=$repo_root/vcpkg/vcpkg
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg first" >&2; exit 2; }
[[ -x $devkit/bin/x86_64-linux-gnu-clang ]] || { echo "Invalid devkit: $devkit" >&2; exit 2; }
kind=results
$reference && kind=reference-results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/$kind/$run_id
work=$repo_root/.work/evaluations/openssl
[[ ! -e $run_dir ]] || { echo "Evidence exists: $run_dir" >&2; exit 2; }
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to reuse unmarked work directory: $work" >&2
    exit 2
fi
mkdir -p "$run_dir/logs/preparation" "$run_dir/generated" "$work"
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1
export LORELEI_DEVKIT=$devkit
install_lane() {
    local lane=$1 triplet=$2
    local log=$run_dir/logs/preparation/vcpkg-$lane.log
    local command=("$vcpkg" install "openssl:$triplet" --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads")
    if $verbose; then
        "${command[@]}" 2>&1 | tee "$log"
    else
        "${command[@]}" >"$log" 2>&1
    fi
}
install_lane native arm64-linux-ae
install_lane guest x64-linux-ae
find "$work/installed/native/arm64-linux-ae/lib" "$work/installed/guest/x64-linux-ae/lib" -maxdepth 1 -type f -name '*.so*' -print -exec file {} \; -exec readelf -d {} \; -exec readelf -Ws {} \; >"$run_dir/generated/shared-library-audit.txt"
python3 - "$run_dir/meta.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
meta = {"schema_version": 2, "package": "openssl", "release": "3.0.22", "mechanism": "TLC Only", "scope": "shared-library installation audit only"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
summary = {"schema_version": 2, "package": "openssl", "status": "installed", "tests_run": False}
pathlib.Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
