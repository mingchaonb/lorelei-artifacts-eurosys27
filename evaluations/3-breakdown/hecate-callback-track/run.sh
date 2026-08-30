#!/usr/bin/env bash
set -euo pipefail

target_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$target_dir/../../.." && pwd)
[[ $# == 0 ]] || { echo "Unexpected positional argument: $1" >&2; exit 2; }
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
iterations=${ITERATIONS:-100000000}
rounds=${ROUNDS:-5}
cpu=${CPU:-0}
state=$repo_root/.work/evaluations/hecate-callback-track
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_dir=$target_dir/results/$run_id

test -x "$devkit/bin/LoreHLR"
taskset -c "$cpu" true
mkdir -p "$state" "$result_dir/raw"
cc -O2 -std=c11 -Wall -Wextra "$target_dir/benchmark.c" -o "$state/benchmark"

{
    date -u --iso-8601=seconds
    uname -a
    lscpu
    uptime
    cc --version
    sha256sum "$devkit/bin/LoreHLR" "$target_dir/benchmark.c" "$state/benchmark"
    printf 'lorelei_devkit=%s\n' "$devkit"
    printf 'production_expression=(uintptr_t)addr < (uintptr_t)emuAddr\n'
    printf 'measured_fast_path=(uintptr_t)addr >= (uintptr_t)emuAddr\n'
    printf 'iterations=%s\nrounds=%s\nselected_cpu=%s\n' "$iterations" "$rounds" "$cpu"
} >"$result_dir/environment.txt" 2>&1

for round in $(seq 1 "$rounds"); do
    taskset -c "$cpu" "$state/benchmark" "$iterations" \
        >"$result_dir/raw/round-$round.stdout" \
        2>"$result_dir/raw/round-$round.stderr"
done

python3 - "$result_dir" "$iterations" <<'PY'
import csv
import pathlib
import re
import statistics
import sys

root = pathlib.Path(sys.argv[1])
iterations = int(sys.argv[2])
pattern = re.compile(
    r"iterations=(\d+) elapsed_ns=(\d+) ns_per_compare=([0-9.]+) host_count=(\d+)"
)
rows = []
for path in sorted((root / "raw").glob("round-*.stdout")):
    match = pattern.fullmatch(path.read_text().strip())
    if not match:
        raise SystemExit(f"invalid output in {path}")
    observed, elapsed, per_compare, host_count = match.groups()
    if int(observed) != iterations or int(host_count) != iterations:
        raise SystemExit(f"incorrect classification in {path}")
    rows.append([path.stem, elapsed, per_compare])

with (root / "summary.csv").open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(["round", "elapsed_ns", "compare_ns"])
    writer.writerows(rows)
    writer.writerow([
        "median",
        statistics.median(int(row[1]) for row in rows),
        statistics.median(float(row[2]) for row in rows),
    ])
PY

echo "Evidence: $result_dir"
