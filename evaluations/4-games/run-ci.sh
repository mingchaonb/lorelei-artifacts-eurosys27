#!/usr/bin/env bash
set -euo pipefail

games_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$games_dir/../.." && pwd)
source "$repo_root/evaluations/common/host-architecture.sh"
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

cleanup_game_processes() {
    local pattern="$repo_root/.work/evaluations/games/.*/installed/"
    pkill -TERM -f "$pattern" 2>/dev/null || true
    sleep 1
    pkill -KILL -f "$pattern" 2>/dev/null || true
}

# A canceled self-hosted run may leave a host game outside any container.
# Limit cleanup to executables installed under this checkout.
cleanup_game_processes
trap cleanup_game_processes EXIT

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
        lane_seconds=$run_seconds
        # RV64 QEMU needs a longer startup window to finish loading game
        # assets before the final ten-second FPS sample. The measured window
        # remains identical across lanes.
        if [[ $AE_HOST_ARCH == riscv64 && $lane == qemu-hecate &&
              $lane_seconds -lt 120 ]]; then
            lane_seconds=120
        fi
        echo
        echo "[$game] initial scene, lane $lane, watchdog ${lane_seconds}s"
        if ! "$games_dir/$game/run.sh" --lane "$lane" "$lane_seconds"; then
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
