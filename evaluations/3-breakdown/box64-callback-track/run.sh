#!/usr/bin/env bash
set -euo pipefail

target_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$target_dir/../../.." && pwd)
[[ $# == 0 ]] || { echo "Unexpected positional argument: $1" >&2; exit 2; }
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
box64=$(realpath -m "${BOX64_CALLBACK_TRACK:-$repo_root/vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track}")
iterations=${ITERATIONS:-1000000}
rounds=${ROUNDS:-5}
cpu=${CPU:-0}
state=$repo_root/.work/evaluations/box64-callback-track
port_state=$repo_root/.work/evaluations/breakdown-test
host_prefix=$port_state/installed/hecate/arm64-linux-ae
guest_prefix=$port_state/installed/guest/x64-linux-ae
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_dir=$target_dir/results/$run_id

test -x "$box64"
test -x "$devkit/bin/x86_64-linux-gnu-clang"
test -f "$host_prefix/lib/libbreakdown_test.so.1"
test -f "$guest_prefix/lib/libbreakdown_test.so.1"
taskset -c "$cpu" true
mkdir -p "$state" "$result_dir/raw"

"$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -O2 \
    -I"$guest_prefix/include" "$target_dir/benchmark.c" \
    -L"$guest_prefix/lib" -Wl,-rpath,"$guest_prefix/lib" \
    -lbreakdown_test -o "$state/benchmark.x86_64"

{
    date -u --iso-8601=seconds
    uname -a
    cat /etc/os-release
    lscpu
    uptime
    taskset -pc $$
    printf 'selected_cpu=%s\n' "$cpu"
    for entry in scaling_driver scaling_governor scaling_cur_freq scaling_min_freq scaling_max_freq; do
        path=/sys/devices/system/cpu/cpu$cpu/cpufreq/$entry
        if test -r "$path"; then
            printf '%s=' "$entry"
            cat "$path"
        fi
    done
    "$box64" --version
    sha256sum "$box64"
    "$repo_root/vcpkg/vcpkg" list | grep '^box64-callback-track-ae:arm64-linux' || true
    printf 'box64_tool=%s\n' "$box64"
    printf 'iterations=%s\nrounds=%s\n' "$iterations" "$rounds"
    printf 'wrapper_signature_checks_per_sample=1000\n'
} >"$result_dir/environment.txt" 2>&1

for round in $(seq 1 "$rounds"); do
    taskset -c "$cpu" env \
        LD_LIBRARY_PATH="$host_prefix/lib" \
        BOX64_LD_LIBRARY_PATH="$guest_prefix/lib" \
        BOX64_LOG=0 \
        BOX64_NOBANNER=1 \
        BOX64_NORCFILES=1 \
        BOX64_DYNAREC=1 \
        BOX64_CALLBACK_TRACK_BENCH=1 \
        "$box64" "$state/benchmark.x86_64" "$iterations" \
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
counts = re.compile(r"BOX64_CALLBACK_TRACK .*samples=(\d+).*")
values = re.compile(
    r"BOX64_CALLBACK_TRACK_NS guest_libs=([0-9.]+) "
    r"host_libs=([0-9.]+) protection=([0-9.]+) "
    r"got=([0-9.]+) wrapper=([0-9.]+) total=([0-9.]+)"
)
correctness = re.compile(
    r"function=breakdown_test_accept_callback iterations=(\d+) accepted=(\d+)"
)
rows = []
for stderr_path in sorted((root / "raw").glob("round-*.stderr")):
    stdout_path = stderr_path.with_suffix(".stdout")
    stderr = stderr_path.read_text()
    stdout = stdout_path.read_text()
    count_match = counts.search(stderr)
    value_match = values.search(stderr)
    correctness_match = correctness.search(stdout)
    if not count_match or not value_match or not correctness_match:
        raise SystemExit(f"missing benchmark output in {stderr_path}")
    samples = int(count_match.group(1))
    requested, accepted = (int(value) for value in correctness_match.groups())
    if samples != iterations or requested != iterations or accepted != iterations:
        raise SystemExit(
            f"invalid result in {stderr_path}: samples={samples} "
            f"requested={requested} accepted={accepted}"
        )
    rows.append([
        stderr_path.stem,
        *(float(value) for value in value_match.groups()),
    ])

with (root / "summary.csv").open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow([
        "round",
        "guest_libs_ns",
        "host_libs_ns",
        "protection_ns",
        "got_ns",
        "wrapper_ns",
        "total_ns",
    ])
    writer.writerows(rows)
    writer.writerow([
        "median",
        *(statistics.median(row[column] for row in rows)
          for column in range(1, 7)),
    ])
PY

echo "Evidence: $result_dir"
