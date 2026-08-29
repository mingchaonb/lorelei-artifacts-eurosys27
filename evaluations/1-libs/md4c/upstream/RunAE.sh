#!/usr/bin/env bash
set -euo pipefail

bench=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$bench/../../../.." && pwd)
work=${WORK:-"$root/build/ae-md4c"}

"$bench/BuildBaselines.sh"
"$bench/BuildThunk.sh"
"$bench/RunLanes.sh"

for lane in native hecate; do
  grep -q '^652 passed, 0 failed, 0 errored, 0 skipped$' \
    "$work/results/${lane}-test.log"
  grep -q '^29 passed, 0 failed, 0 errored$' \
    "$work/results/${lane}-test-pathological.log"
done
[[ $(grep -c ' passed, 0 failed, 0 errored, 0 skipped$' \
  "$work/results/hecate-test.log") -eq 10 ]]
grep -q '^md_html$' "$work/dump/functions.txt"
cp "$work/thunk/.gen/md4c-html/ThunkStat.json" "$work/dump/ThunkStat.json"

cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "0.5.3",
  "commit": "472c417005c2c71b8617de4f7b8d6b30411d78f4",
  "upstream_tests": 818,
  "functions": 1,
  "callbacks": 1,
  "adaptation": "TLC only"
}
EOF
cat "$work/results/summary.json"
