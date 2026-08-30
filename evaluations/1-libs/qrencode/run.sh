#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../.common/run-tlc-only.sh" qrencode qrencode libqrencode.so "$@"
