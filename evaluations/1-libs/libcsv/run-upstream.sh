#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
reference=false
positional=()
for arg in "$@"; do
  case "$arg" in
    --reference) reference=true ;;
    --verbose) ;;
    -h|--help) echo "Usage: $0 [--reference] /path/to/lorelei-devkit"; exit 0 ;;
    --*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) positional+=("$arg") ;;
  esac
done
[[ ${#positional[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${positional[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
[[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
work=$repo_root/.work/evaluations/libcsv-upstream
results_root=$recipe_dir/upstream-results
$reference && results_root=$recipe_dir/upstream-reference-results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
  echo "Refusing unmarked work directory: $work" >&2
  exit 2
fi
if [[ -e $work ]]; then cmake -E remove_directory "$work"; fi
mkdir -p "$work" "$run_dir/logs"
touch "$work/.lorelei-evaluations-workspace"
set +e
WORK="$work" DEVKIT="$devkit" QEMU="$qemu" "$recipe_dir/upstream/RunAE.sh" 2>&1 | tee "$run_dir/commands.log"
status=${PIPESTATUS[0]}
set -e
mkdir -p "$work"
touch "$work/.lorelei-evaluations-workspace"
if [[ -d $work/results ]]; then cp -a "$work/results/." "$run_dir/logs/"; fi
python3 - "$run_dir/summary.json" "$work/results/summary.json" "$status" <<'PY'
import json, pathlib, sys
out, legacy, status = sys.argv[1:]
data = json.loads(pathlib.Path(legacy).read_text()) if pathlib.Path(legacy).is_file() else {}
data.update({"schema_version": 2, "package": "libcsv", "suite": "configured upstream", "status": "pass" if status == "0" else "fail", "native": {"exit_status": 0 if status == "0" else None}, "hecate": {"exit_status": int(status)}, "pure_qemu_run": False})
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
exit "$status"
