#!/usr/bin/env bash
set -euo pipefail

games_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$games_dir/../.." && pwd)
run_seconds=${1:-30}

if [[ ! $run_seconds =~ ^[0-9]+$ ]] || ((run_seconds < 25)); then
    echo "The CI watchdog must be an integer of at least 25 seconds." >&2
    exit 2
fi

games=(supertux supertuxkart assaultcube redeclipse openarena)
lanes=(native qemu-hecate box64 box64-hecate)
run_id=${GITHUB_RUN_ID:-local}-$(date -u +%Y%m%dT%H%M%SZ)
history=$repo_root/.work/evaluations/games/ci-result-history/$run_id
mkdir -p "$history"

# Keep a CI batch independent from older interactive measurements. Previous
# result directories remain recoverable below .work instead of being deleted.
for game in "${games[@]}"; do
    if [[ -d $games_dir/$game/results ]]; then
        mv "$games_dir/$game/results" "$history/$game"
    fi
    mkdir -p "$games_dir/$game/results"
done

failed=0
for game in "${games[@]}"; do
    for lane in "${lanes[@]}"; do
        echo
        echo "[$game] initial scene, lane $lane"
        if ! "$games_dir/$game/run.sh" --lane "$lane" "$run_seconds"; then
            echo "Game runner failed: $game, $lane" >&2
            failed=1
        fi
    done
done

python3 "$repo_root/evaluations/export-paper-data.py" \
    --output "$repo_root/evaluations/paper-data"
if ! python3 "$games_dir/_common/validate-ci-fps.py" \
    "$repo_root/evaluations/paper-data/game-fps.csv" \
    "$repo_root/evaluations/paper-data/game-fps-ci.csv"; then
    failed=1
fi

echo "CI game FPS table: $repo_root/evaluations/paper-data/game-fps-ci.csv"
exit "$failed"
