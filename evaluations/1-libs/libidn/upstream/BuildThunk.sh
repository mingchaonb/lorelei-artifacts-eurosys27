#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
devkit=${DEVKIT:-"$root/build/install"}
work=${WORK:-"$root/build/ae-libidn"}
host_so="$work/native/lib/.libs/libidn.so.12.6.6"

find "$work/guest/tests" -maxdepth 1 -type f -perm -111 -print0 \
  | while IFS= read -r -d '' test_binary; do
      if file "$test_binary" | grep -q 'ELF 64-bit LSB pie executable, x86-64'; then
        llvm-nm-20 -D --undefined-only --just-symbol-name "$test_binary"
      fi
    done | sed 's/@.*//' | sort -u > "$work/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_so" \
  | awk '$2 == "T" || $2 == "W" { n=$1; sub(/@.*/, "", n); print n }' \
  | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
  > "$work/dump/functions.txt"
sed '1i[Function]' "$work/dump/functions.txt" > "$work/dump/Symbols.conf"
readelf -Ws "$host_so" > "$work/dump/host-symbols.txt"
awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" && $7 != "UND" && $7 != "ABS" { print $8 }' \
  "$work/dump/host-symbols.txt" | sed 's/@.*//' | sort -u > "$work/dump/host-data-tls.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-data-tls.txt" \
  > "$work/dump/data-used.txt"

cat > "$work/dump/Api.c" <<'EOF'
#include <idna.h>
#include <punycode.h>
#include <stringprep.h>
#include <tld.h>
EOF
cat > "$work/dump/compile_commands.json" <<EOF
[
  {
    "directory": "$work/dump",
    "arguments": [
      "/usr/bin/clang-20", "-include", "$work/native/config.h",
      "-I$work/native/lib", "-I$work/native/lib/gl",
      "-I$work/source/lib", "-c", "$work/dump/Api.c"
    ],
    "file": "$work/dump/Api.c"
  }
]
EOF
"$devkit/bin/LoreTLC" dump -c "$work/dump/Symbols.conf" \
  -p "$work/dump" "$work/dump/Api.c" -o "$work/dump/Desc.dump.h" \
  > "$work/results/tlc-dump.log" 2>&1

mkdir -p "$work/guest-data"
cp "$work/guest/lib/.libs/libidn.so.12.6.6" "$work/guest-data/libidn-data.so"
patchelf=${PATCHELF:-"$(dirname "$devkit")/ae-tools/patchelf-root/usr/bin/patchelf"}
"$patchelf" \
  --set-soname libidn-data.so "$work/guest-data/libidn-data.so"

rm -rf "$work/thunk"
"$devkit/bin/LoreMakeThunk.py" --name idn -o "$work/thunk" \
  --lib "$host_so" --symbols "$work/dump/Symbols.conf" \
  --desc "$work/dump/Desc.dump.h" \
  --devkit "$devkit" --keep-intermediates \
  --gtl-arg=-Wl,--no-as-needed --gtl-arg=-L"$work/guest-data" \
  --gtl-arg=-l:libidn-data.so --gtl-arg=-Wl,--as-needed -- \
  -include "$work/native/config.h" -I"$work/native/lib" \
  -I"$work/native/lib/gl" -I"$work/source/lib" \
  > "$work/results/thunk-build.log" 2>&1

printf 'functions=%s data=%s\n' \
  "$(wc -l < "$work/dump/functions.txt")" \
  "$(wc -l < "$work/dump/data-used.txt")"
