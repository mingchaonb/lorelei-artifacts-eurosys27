#!/usr/bin/env bash
set -euo pipefail

evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
run_id=${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$(date -u +%Y%m%dT%H%M%SZ)
archive_root=$repo_root/.work/evaluations/ci-result-history/$run_id
mkdir -p "$archive_root"

# Keep generated evidence from this workflow independent from any previous
# interactive or CI batch. All moved data remains recoverable under .work.
mapfile -t result_dirs < <(
    find \
        "$evaluations_dir/1-libs" \
        "$evaluations_dir/2-cli-benchmarks" \
        "$evaluations_dir/3-breakdown" \
        "$evaluations_dir/4-games" \
        "$evaluations_dir/5-modifications" \
        -type d -name results -prune | sort
)
for source in "${result_dirs[@]}"; do
    relative=${source#"$evaluations_dir/"}
    destination=$archive_root/results/$relative
    mkdir -p "$(dirname "$destination")"
    mv "$source" "$destination"
done

mkdir -p "$archive_root/paper-data"
shopt -s nullglob
paper_outputs=("$evaluations_dir"/paper-data/*.csv)
if [[ -f $evaluations_dir/paper-data/manifest.json ]]; then
    paper_outputs+=("$evaluations_dir/paper-data/manifest.json")
fi
for source in "${paper_outputs[@]}"; do
    mv "$source" "$archive_root/paper-data/"
done

echo "Previous generated evidence archived at $archive_root"
