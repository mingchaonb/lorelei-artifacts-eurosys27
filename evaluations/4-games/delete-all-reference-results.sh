#!/usr/bin/env bash
set -euo pipefail

base_dir=$(cd "$(dirname "$0")" && pwd)
dry_run=false
if [[ ${1:-} == --dry-run ]]; then
    dry_run=true
elif (($#)); then
    echo "Usage: $0 [--dry-run]" >&2
    exit 2
fi

deleted=0
while IFS= read -r -d '' target; do
    target=$(realpath "$target")
    [[ $(basename "$target") == reference-results ]] || { echo "Refusing unexpected target: $target" >&2; exit 1; }
    [[ $(dirname "$(dirname "$target")") == "$base_dir" ]] || { echo "Refusing out-of-scope target: $target" >&2; exit 1; }
    if $dry_run; then
        echo "Would delete: $target"
    else
        echo "Deleting: $target"
        rm -rf -- "$target"
    fi
    ((deleted += 1))
done < <(find "$base_dir" -mindepth 2 -maxdepth 2 -type d -name reference-results -print0 | sort -z)

if ((deleted == 0)); then
    echo "No reference-results directories found"
elif $dry_run; then
    echo "Matched $deleted reference-results directories"
else
    echo "Deleted $deleted reference-results directories"
fi
