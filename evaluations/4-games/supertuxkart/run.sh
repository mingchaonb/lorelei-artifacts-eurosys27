#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "$0")" && pwd)
GAME_RUNNER_NAME="$0" exec "$recipe_dir/../.common/run-game.sh" supertuxkart "$@"
