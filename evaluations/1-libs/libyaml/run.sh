#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../.common/run-tlc-only.sh" libyaml yaml libyaml.so "$@"
