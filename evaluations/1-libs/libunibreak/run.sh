#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../libmaxminddb/run-tlc-only.sh" libunibreak unibreak libunibreak.so.7 "$@"
