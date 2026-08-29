#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
bench=$(cd "$(dirname "$0")" && pwd)
devkit=${DEVKIT:-"$root/build/install"}
work=${WORK:-"$root/build/ae-libidn"}
shim="$bench/libc-shim"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
rm -rf "$work/thunk-libc-shim"
"$devkit/bin/LoreMakeThunk.py" --name c-shim -o "$work/thunk-libc-shim" \
  --lib "$host_libc" --soname libc-shim.so \
  --symbols "$shim/Symbols.conf" --desc "$shim/Desc.h" \
  --manifest-host "$shim/Manifest_host.cpp" \
  --manifest-guest "$shim/Manifest_guest.cpp" \
  --devkit "$devkit" --keep-intermediates -- \
  -D_GNU_SOURCE -I"$bench/include" \
  > "$work/results/libc-shim-build.log" 2>&1
ln -s "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

find "$work/guest/tests" -maxdepth 1 -type f -perm -111 -print0 \
  | while IFS= read -r -d '' test_binary; do
      if file "$test_binary" | grep -q 'ELF 64-bit LSB pie executable, x86-64'; then
        real="$test_binary.lore-real"
        mv "$test_binary" "$real"
        printf '%s\n' '#!/usr/bin/env bash' \
          'exec '"$bench"'/LaneRunner.sh "'"$real"'" "$@"' \
          > "$test_binary"
        chmod +x "$test_binary"
      fi
    done

for lane in hecate; do
  hecate=0
  [[ "$lane" == hecate ]] && hecate=1
  (cd "$work/guest" && env LORE_AE_HECATE="$hecate" make -j1 check) \
    > "$work/results/${lane}-test.log" 2>&1 || true
  grep -E '^# TOTAL:|^# PASS:|^# SKIP:|^# FAIL:|^# ERROR:' \
    "$work/results/${lane}-test.log" | tail -5
done
