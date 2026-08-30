#!/usr/bin/env bash
set -euo pipefail

target_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$target_dir/../../.." && pwd)
devkit=${1:-$repo_root/../lorelei-ae/build/install}
qemu=${QEMU:-$repo_root/../qemu-ae/build/qemu-x86_64}
iterations=${ITERATIONS:-1000000}
rounds=${ROUNDS:-5}
overlay=$repo_root/vcpkg-overlay
state=$repo_root/.work/evaluations/zlib-version-breakdown
zlib_state=$repo_root/.work/evaluations/zlib
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_dir=$target_dir/results/$run_id
host_prefix=$zlib_state/installed/hecate/arm64-linux-ae
thunk=$state/thunk

test -x "$qemu"
test -x "$devkit/bin/LoreMakeThunk.py"
test -x "$devkit/bin/x86_64-linux-gnu-clang"
if test ! -f "$host_prefix/include/zlib.h"; then
    echo "zlib is not installed by evaluations/1-libs/zlib" >&2
    echo "Run evaluations/1-libs/zlib/run.sh --install-only first" >&2
    exit 2
fi
mkdir -p "$state" "$result_dir/raw"
host_lib=$(find "$host_prefix/lib" -maxdepth 1 -type f -name 'libz.so.*' | sort | head -n 1)
test -n "$host_lib"
printf '[Function]\nzlibVersion\n' >"$state/Symbols.conf"

"$devkit/bin/LoreMakeThunk.py" \
    --name z \
    --out "$thunk" \
    --lib "$host_lib" \
    --symbols "$state/Symbols.conf" \
    --desc "$overlay/ports/zlib/lorelei/Desc.h" \
    --gtl-alias libz.so.1 \
    --devkit "$devkit" \
    --keep-intermediates \
    -- -I"$host_prefix/include" >"$result_dir/thunk.log" 2>&1

guest_source=$thunk/.gen/z/Thunk_guest.cpp
python3 "$target_dir/instrument-generated-thunk.py" "$guest_source"

"$devkit/bin/x86_64-linux-gnu-clang++" \
    --sysroot="$devkit/x86_64/sysroot" \
    -shared -std=gnu++20 -fPIC -fvisibility=hidden \
    -fvisibility-inlines-hidden -fno-exceptions -fno-rtti \
    -I"$devkit/x86_64/include" -I"$thunk/.gen/z" -I"$host_prefix/include" \
    "$guest_source" -o "$thunk/x86_64/libz.so" \
    -L"$devkit/x86_64/lib" -lLoreGuestRT -Wl,-soname,libz.so.1 \
    >"$result_dir/instrumented-thunk-build.log" 2>&1
ln -sfn libz.so "$thunk/x86_64/libz.so.1"

"$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" -O2 \
    -I"$host_prefix/include" "$target_dir/benchmark.c" \
    -L"$thunk/x86_64" -Wl,-rpath,"$thunk/x86_64" -lz \
    -o "$state/benchmark.x86_64"

{
    date -u --iso-8601=seconds
    uname -a
    lscpu
    uptime
    "$qemu" --version
    git -C "$repo_root/../qemu-ae" rev-parse HEAD
    git -C "$repo_root/../lorelei-ae" rev-parse HEAD
    printf 'function=zlibVersion\niterations=%s\nrounds=%s\n' "$iterations" "$rounds"
} >"$result_dir/environment.txt" 2>&1

for round in $(seq 1 "$rounds"); do
    env LD_LIBRARY_PATH="$devkit/lib:$host_prefix/lib:$thunk" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E LD_BIND_NOW=1 \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$thunk/x86_64" \
        "$state/benchmark.x86_64" "$iterations" \
        >"$result_dir/raw/round-$round.stdout" \
        2>"$result_dir/raw/round-$round.stderr"
done

python3 - "$result_dir" <<'PY'
import csv
import pathlib
import re
import statistics
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(
    r"LORELEI_BREAKDOWN_NS_PER_CALL gtl=([0-9.]+) hecmid=([0-9.]+) "
    r"qemu=([0-9.]+) htl=([0-9.]+) total=([0-9.]+)"
)
rows = []
for path in sorted((root / "raw").glob("round-*.stderr")):
    match = pattern.search(path.read_text())
    if not match:
        raise SystemExit(f"missing breakdown output in {path}")
    rows.append([path.stem, *(float(value) for value in match.groups())])

with (root / "summary.csv").open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(["round", "gtl_ns", "hecmid_ns", "qemu_ns", "htl_ns", "total_ns"])
    writer.writerows(rows)
    writer.writerow([
        "median",
        *(statistics.median(row[column] for row in rows) for column in range(1, 6)),
    ])
PY

echo "Evidence: $result_dir"
