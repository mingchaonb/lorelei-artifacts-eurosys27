#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GAME_RUNNER_NAME="$0" exec "$recipe_dir/../_common/run-game.sh" supertux "$@"
