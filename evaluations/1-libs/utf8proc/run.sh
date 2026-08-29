#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../libmaxminddb/run-tlc-only.sh" utf8proc utf8proc libutf8proc.so.3 "$@"
