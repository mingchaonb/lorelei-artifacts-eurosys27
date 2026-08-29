#!/usr/bin/env bash
set -euo pipefail

bench=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$bench/../../../.." && pwd)
work=${WORK:-"$root/build/ae-libidn"}
archive=${LIBIDN_ARCHIVE:-"$root/../ae-libs/libidn-1.43.tar.gz"}

expected_sha256=bdc662c12d041b2539d0e638f3a6e741130cdb33a644ef3496963a443482d164
actual_sha256=$(sha256sum "$archive" | awk '{print $1}')
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "libidn 1.43 archive checksum mismatch" >&2
    exit 1
fi

"$bench/BuildBaselines.sh"
"$bench/BuildThunk.sh"
"$bench/RunLanes.sh"

grep -q '# TOTAL: 17' "$work/results/native-test.log"
grep -q '# PASS:  17' "$work/results/native-test.log"
grep -q '# PASS:  17' "$work/results/hecate-test.log"
cp "$work/thunk/.gen/idn/ThunkStat.json" "$work/dump/ThunkStat.json"

cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "1.43",
  "archive_sha256": "$actual_sha256",
  "upstream_tests": 17,
  "functions": $(wc -l < "$work/dump/functions.txt"),
  "guest_data_references": $(wc -l < "$work/dump/data-used.txt"),
  "adaptation": "TLC plus libc-shim"
}
EOF
cat "$work/results/summary.json"
