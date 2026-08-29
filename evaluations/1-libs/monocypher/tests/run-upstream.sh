#!/usr/bin/env bash
set -euo pipefail
: "${DEVKIT:?}"
: "${QEMU:?}"
: "${WORK:?}"
: "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}"
devkit=$DEVKIT
qemu=$QEMU
work=$WORK
guest_sysroot=$devkit/x86_64/sysroot
commit=ab2b16dd619ad5f6979a4fbe69cfa324a6fcc35f
archive_sha256=8cc9bc341a66249016db9bd70e9142d8d0aef9945973744b1ac05dbc55d8ee66
cmake -E remove_directory "$work"
mkdir -p "$work/results" "$work/dump"
host_lib=$NATIVE_PREFIX/lib/libmonocypher.so.4
native_test=$NATIVE_PREFIX/tools/monocypher/upstream-tests/test.out
guest_test=$GUEST_PREFIX/tools/monocypher/upstream-tests/test.out
[[ -x $native_test && -x $guest_test ]] || { echo "Installed upstream tests are missing" >&2; exit 2; }

readelf -d "$guest_test" > "$work/dump/guest-test-dynamic.txt"
grep -q 'libmonocypher.so.4' "$work/dump/guest-test-dynamic.txt"
env LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$native_test" \
  > "$work/results/native-test.log" 2>&1

llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_test" \
  | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix \
  "$host_lib" \
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
#include "monocypher.h"
#include "monocypher-ed25519.h"
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
"$devkit/bin/LoreMakeThunk.py" --name monocypher -o "$work/thunk" \
  --lib "$host_lib" \
  --symbols "$work/dump/Symbols.conf" --desc "$work/dump/Desc.dump.h" \
  --devkit "$devkit" --keep-intermediates -- \
  -I"$NATIVE_PREFIX/include" \
  > "$work/results/thunk-build.log" 2>&1

env LD_LIBRARY_PATH="$devkit/lib:$NATIVE_PREFIX/lib:$work/thunk" \
  "$qemu" -L "$guest_sysroot" -E LD_BIND_NOW=1 \
  -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" \
  "$guest_test" > "$work/results/hecate-test.log" 2>&1
cmp "$work/results/native-test.log" "$work/results/hecate-test.log"
grep -q '^All tests OK!$' "$work/results/hecate-test.log"
[[ ! -s "$work/dump/data-used.txt" ]]
cp "$work/thunk/.gen/monocypher/ThunkStat.json" \
  "$work/dump/ThunkStat.json"
function_count=$(wc -l < "$work/dump/functions.txt")
exported_data_count=$(wc -l < "$work/dump/host-data-tls.txt")

cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "4.0.3",
  "commit": "$commit",
  "release_archive_sha256": "$archive_sha256",
  "upstream_test_programs": 1,
  "functions": $function_count,
  "callbacks": 0,
  "exported_data_tls": $exported_data_count,
  "guest_data_references": 0,
  "adaptation": "TLC only"
}
EOF
cat "$work/results/summary.json"
