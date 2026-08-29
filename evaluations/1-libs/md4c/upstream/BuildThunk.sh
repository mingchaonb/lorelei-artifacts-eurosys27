#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
devkit=${DEVKIT:-$root/build/install}
work=${WORK:-$root/build/ae-md4c}
host_so=$work/native/src/libmd4c-html.so.0.5.3

llvm-nm-20 -D --undefined-only --just-symbol-name \
  "$work/guest/md2html/md2html" \
  | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_so" \
  | awk '$2 == "T" || $2 == "W" { n=$1; sub(/@.*/, "", n); print n }' \
  | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
  > "$work/dump/functions.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"

cat > "$work/dump/Api.c" <<'EOF'
#include <md4c.h>
#include <md4c-html.h>
EOF
cat > "$work/dump/compile_commands.json" <<EOF
[
  {
    "directory": "$work/dump",
    "arguments": [
      "/usr/bin/clang-20", "-I$work/source/src", "-c", "$work/dump/Api.c"
    ],
    "file": "$work/dump/Api.c"
  }
]
EOF

"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
  -p "$work/dump" "$work/dump/Api.c" -o "$work/dump/Desc.dump.h" \
  > "$work/results/tlc-dump.log" 2>&1

rm -rf "$work/thunk"
"$devkit/bin/LoreMakeThunk.py" --name md4c-html -o "$work/thunk" \
  --lib "$host_so" --symbols "$work/dump/Symbols.conf" \
  --desc "$work/dump/Desc.dump.h" --devkit "$devkit" \
  --keep-intermediates -- -I"$work/source/src" \
  > "$work/results/thunk-build.log" 2>&1
