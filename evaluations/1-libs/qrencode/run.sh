#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/../_common/run-tlc-only.sh" qrencode qrencode libqrencode.so "$@"
