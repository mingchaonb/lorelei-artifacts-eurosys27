#!/usr/bin/env bash
set -euo pipefail

target_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$target_dir/../.." && pwd)
source_root=$repo_root/.work/evaluations/modifications/sources
run_id=$(date -u +%Y%m%dT%H%M%SZ)
result_dir=$target_dir/results/$run_id

[[ $# == 0 ]] || { echo "Unexpected positional argument: $1" >&2; exit 2; }
mkdir -p "$source_root" "$result_dir"

python3 - "$target_dir/sources.json" <<'PY' | while IFS=$'\t' read -r name url base head; do
import json
import sys

for name, source in json.load(open(sys.argv[1])).items():
    print(name, source["url"], source["base"], source["head"], sep="\t")
PY
    checkout=$source_root/$name
    if [[ ! -d $checkout/.git ]]; then
        echo "Clone $name"
        git clone --filter=blob:none --no-checkout "$url" "$checkout"
    fi
    echo "Fetch pinned revisions for $name"
    git -C "$checkout" remote set-url origin "$url"
    git -C "$checkout" fetch --no-tags origin "$base" "$head"
    git -C "$checkout" checkout --detach --force "$head"
done

python3 "$target_dir/analyze.py" \
    --sources "$target_dir/sources.json" \
    --source-root "$source_root" \
    --output "$result_dir"

{
    date -u --iso-8601=seconds
    uname -a
    git --version
    sha256sum "$target_dir/analyze.py" "$target_dir/sources.json"
} >"$result_dir/environment.txt"

column -s, -t <"$result_dir/summary.csv" 2>/dev/null || cat "$result_dir/summary.csv"
echo "Evidence: $result_dir"
