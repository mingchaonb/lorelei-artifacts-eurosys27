#!/usr/bin/env bash
set -euo pipefail
: "${DEVKIT:?}"
: "${QEMU:?}"
: "${WORK:?}"
: "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}"
devkit=$DEVKIT
qemu=$QEMU
work=$WORK
cmake -E remove_directory "$work"
mkdir -p "$work/results" "$work/dump"
host_lib=$NATIVE_PREFIX/lib/libsha2.so
native_test=$NATIVE_PREFIX/tools/libsha2/upstream-tests/test
guest_test=$GUEST_PREFIX/tools/libsha2/upstream-tests/test
guest_cc=$devkit/bin/x86_64-linux-gnu-clang
guest_sysroot=$devkit/x86_64/sysroot
[[ -x $native_test && -x $guest_test ]] || { echo "Installed upstream tests are missing" >&2; exit 2; }

readelf -d "$guest_test" > "$work/dump/guest-test-dynamic.txt"
grep -q 'libsha2.so' "$work/dump/guest-test-dynamic.txt"
/usr/bin/time -f 'native_seconds=%e maxrss_kb=%M' \
  env LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$native_test" \
  > "$work/results/native-test.log" 2> "$work/results/native-time.log"
llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_test" \
  | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_lib" \
  | awk '$2 == "T" || $2 == "W" {print $1}' | sort -u \
  > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
  > "$work/dump/functions.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"
readelf -Ws "$host_lib" \
  | awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" && $7 != "UND" && $7 != "ABS" {print $8}' \
  | sed 's/@.*//' | sort -u > "$work/dump/host-data-tls.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-data-tls.txt" \
  > "$work/dump/data-used.txt"

cat > "$work/dump/Api.c" <<'EOF'
#include "sha-256.h"
EOF
cat > "$work/dump/compile_commands.json" <<EOF
[
  {
    "directory": "$work/dump",
    "arguments": [
      "/usr/bin/clang-20", "-I$NATIVE_PREFIX/include", "-c", "$work/dump/Api.c"
    ],
    "file": "$work/dump/Api.c"
  }
]
EOF
"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
  -p "$work/dump" "$work/dump/Api.c" -o "$work/dump/Desc.dump.h" \
  > "$work/results/tlc-dump.log" 2>&1
"$devkit/bin/LoreMakeThunk.py" --name sha2 -o "$work/thunk" \
  --lib "$host_lib" --symbols "$work/dump/Symbols.conf" \
  --desc "$work/dump/Desc.dump.h" --devkit "$devkit" \
  --keep-intermediates -- -I"$NATIVE_PREFIX/include" \
  > "$work/results/thunk-build.log" 2>&1

/usr/bin/time -f 'hecate_seconds=%e maxrss_kb=%M' env \
  LD_LIBRARY_PATH="$devkit/lib:$NATIVE_PREFIX/lib:$work/thunk" \
  "$qemu" -L "$guest_sysroot" -E LD_BIND_NOW=1 \
  -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" \
  "$guest_test" > "$work/results/hecate-test.log" \
  2> "$work/results/hecate-time.log"
cmp "$work/results/native-test.log" "$work/results/hecate-test.log"
test "$(rg -c '^SUCCESS!$' "$work/results/hecate-test.log")" -eq 37
if rg -n '^FAILURE!$' "$work/results/hecate-test.log"; then
  exit 3
fi
[[ ! -s "$work/dump/data-used.txt" ]]
cp "$work/thunk/.gen/sha2/ThunkStat.json" "$work/dump/ThunkStat.json"
function_count=$(wc -l < "$work/dump/functions.txt")

cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "version": "pinned upstream snapshot",
  "commit": "565f65009bdd98267361b17d50cddd7c9beb3e6c",
  "successful_checks": 37,
  "largest_input_bytes": 1610612798,
  "functions": $function_count,
  "callbacks": 0,
  "guest_data_references": 0,
  "adaptation": "TLC only"
}
EOF
cat "$work/results/native-time.log" "$work/results/hecate-time.log"
cat "$work/results/summary.json"
