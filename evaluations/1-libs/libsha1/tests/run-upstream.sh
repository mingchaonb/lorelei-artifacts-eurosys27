#!/usr/bin/env bash
set -euo pipefail

tlc_wrapper=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_common" && pwd)/lore-make-thunk.py
: "${LORELEI_DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}"
devkit=$LORELEI_DEVKIT
qemu=$QEMU
work=$WORK
cmake -E remove_directory "$work"
mkdir -p "$work/results" "$work/dump"
host_lib=$NATIVE_PREFIX/lib/libsha1.so
native_test=$NATIVE_PREFIX/tools/libsha1/upstream-tests/test
guest_test=$GUEST_PREFIX/tools/libsha1/upstream-tests/test
[[ -x $native_test && -x $guest_test ]] || { echo "Installed upstream tests are missing" >&2; exit 2; }

readelf -d "$guest_test" > "$work/dump/guest-test-dynamic.txt"
grep -q 'libsha1.so' "$work/dump/guest-test-dynamic.txt"
env LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$native_test" \
  > "$work/results/native-test.log" 2>&1
llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_test" \
  | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_lib" \
  | awk '$2 == "T" || $2 == "W" {print $1}' | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
  > "$work/dump/functions.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"

cat > "$work/dump/Api.c" <<'EOF'
#include "sha1.h"
EOF
cat > "$work/dump/compile_commands.json" <<EOF
[{"directory":"$work/dump","arguments":["/usr/bin/clang-20","-I$NATIVE_PREFIX/include","-c","$work/dump/Api.c"],"file":"$work/dump/Api.c"}]
EOF
"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" -p "$work/dump" \
  "$work/dump/Api.c" -o "$work/dump/Desc.dump.h" > "$work/results/tlc-dump.log" 2>&1
"$tlc_wrapper" "$devkit/bin/LoreMakeThunk.py" --name sha1 -o "$work/thunk" \
  --lib "$host_lib" --symbols "$work/dump/Symbols.conf" \
  --desc "$work/dump/Desc.dump.h" --devkit "$devkit" --keep-intermediates \
  -- -I"$NATIVE_PREFIX/include" > "$work/results/thunk-build.log" 2>&1

env LD_LIBRARY_PATH="$devkit/lib:$NATIVE_PREFIX/lib:$work/thunk" \
  "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
  -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64:$GUEST_PREFIX/lib" \
  "$guest_test" > "$work/results/hecate-test.log" 2>&1
sed -E '/^Elapsed [Tt]ime[[:space:]]*=/d' "$work/results/native-test.log" > "$work/results/native-normalized.log"
sed -E '/^Elapsed [Tt]ime[[:space:]]*=/d' "$work/results/hecate-test.log" > "$work/results/hecate-normalized.log"
cmp "$work/results/native-normalized.log" "$work/results/hecate-normalized.log"
grep -q 'tests[[:space:]]*6[[:space:]]*6[[:space:]]*6[[:space:]]*0' "$work/results/hecate-test.log"
cp "$work/thunk/.gen/sha1/ThunkStat.json" "$work/dump/ThunkStat.json"
function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "release": "0.1.0",\n  "upstream_tests": 6,\n  "functions": %s,\n  "adaptation": "TLC only"\n}\n' \
  "$function_count" > "$work/results/summary.json"
cat "$work/results/summary.json"
