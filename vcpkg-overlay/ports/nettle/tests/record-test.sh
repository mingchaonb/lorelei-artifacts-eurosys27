#!/usr/bin/env bash
set -euo pipefail
: "${LORELEI_TEST_MANIFEST:?LORELEI_TEST_MANIFEST is required}"
printf '%s\n' "$1" >> "$LORELEI_TEST_MANIFEST"
