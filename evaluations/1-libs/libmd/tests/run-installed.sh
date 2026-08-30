#!/usr/bin/env bash
set -euo pipefail
: "${LORELEI_DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}" "${BENCH:?}"
cmake -E remove_directory "$WORK"
mkdir -p "$WORK/results" "$WORK/dump"
tests=(md2 md4 md5 rmd160 sha1 sha2 sha3)
host_lib=$(find "$NATIVE_PREFIX/lib" -maxdepth 1 -type f -name 'libmd.so.*' | head -1)
guest_lib=$(find "$GUEST_PREFIX/lib" -maxdepth 1 -type f -name 'libmd.so.*' | head -1)
: > "$WORK/dump/guest-undefined.txt"
for name in "${tests[@]}"; do
  binary=$GUEST_PREFIX/tools/libmd/upstream-tests/$name
  [[ -x $binary ]] || { echo "Installed upstream test missing: $binary" >&2; exit 2; }
  llvm-nm-20 -D --undefined-only --just-symbol-name "$binary" | sed 's/@.*//' >> "$WORK/dump/guest-undefined.txt"
done
sort -u -o "$WORK/dump/guest-undefined.txt" "$WORK/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u > "$WORK/dump/host-functions.txt"
comm -12 "$WORK/dump/guest-undefined.txt" "$WORK/dump/host-functions.txt" > "$WORK/dump/functions.txt"
sed '1i[Function]' "$WORK/dump/functions.txt" > "$WORK/dump/Symbols.conf"
version_map=$WORK/dump/guest-version.map
: > "$version_map"
parent=
for version in LIBMD_0.0 LIBMD_0.1 LIBMD_0.2; do
  echo "$version {" >> "$version_map"
  echo 'global:' >> "$version_map"
  while read -r fn; do
    readelf -Ws "$guest_lib" | awk -v fn="$fn" -v ver="$version" '$8 == fn "@@" ver {found=1} END {exit !found}' && echo "  $fn;" >> "$version_map"
  done < "$WORK/dump/functions.txt"
  if [[ -z $parent ]]; then printf 'local:\n  *;\n};\n' >> "$version_map"; else echo "} $parent;" >> "$version_map"; fi
  parent=$version
done
"$LORELEI_DEVKIT/bin/LoreMakeThunk.py" --name md -o "$WORK/thunk" --lib "$host_lib" \
  --symbols "$WORK/dump/Symbols.conf" --desc "$BENCH/Desc.h" --devkit "$LORELEI_DEVKIT" \
  --keep-intermediates --gtl-arg="-Wl,--undefined-version" \
  --gtl-arg="-Wl,--version-script=$version_map" -- -I"$NATIVE_PREFIX/include" \
  > "$WORK/results/thunk.log" 2>&1
: > "$WORK/results/native.log"
: > "$WORK/results/hecate.log"
for name in "${tests[@]}"; do
  echo "RUN $name" >> "$WORK/results/native.log"
  LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$NATIVE_PREFIX/tools/libmd/upstream-tests/$name" >> "$WORK/results/native.log" 2>&1
  echo "RUN $name" >> "$WORK/results/hecate.log"
  env LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib:$NATIVE_PREFIX/lib:$WORK/thunk" \
    "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E "LD_LIBRARY_PATH=$LORELEI_DEVKIT/x86_64/lib:$WORK/thunk/x86_64" \
    "$GUEST_PREFIX/tools/libmd/upstream-tests/$name" >> "$WORK/results/hecate.log" 2>&1
done
cmp "$WORK/results/native.log" "$WORK/results/hecate.log"
cp "$WORK/thunk/.gen/md/ThunkStat.json" "$WORK/dump/ThunkStat.json"
printf '{"status":"pass","upstream_tests":7}\n' > "$WORK/results/summary.json"
cat "$WORK/results/summary.json"
