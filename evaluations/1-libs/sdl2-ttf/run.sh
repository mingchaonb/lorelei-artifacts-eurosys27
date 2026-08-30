#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/../.common/run-tlc-only.sh" sdl2-ttf SDL2_ttf libSDL2_ttf-2.0.so.0 "$@"
