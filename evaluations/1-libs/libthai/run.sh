#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../.common/run-tlc-only.sh" libthai thai libthai.so.0 "$@"
