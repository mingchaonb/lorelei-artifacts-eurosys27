#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
devkit=${DEVKIT:-$root/build/install}
source_repo=$base/ae-libs/md4c
work=${WORK:-$root/build/ae-md4c}
commit=472c417005c2c71b8617de4f7b8d6b30411d78f4

actual_commit=$(git -C "$source_repo" rev-parse 'release-0.5.3^{}')
if [[ "$actual_commit" != "$commit" ]]; then
  echo "MD4C release-0.5.3 commit mismatch" >&2
  exit 1
fi

rm -rf "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" \
  "$work/results" "$work/dump"
git -C "$source_repo" archive "$commit" | tar -x -C "$work/source"

if rg -n '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
  "$work/source/src" "$work/source/md2html" \
  > "$work/dump/production-setjmp.txt"; then
  echo "production non-local jump found" >&2
  exit 2
fi

cmake -S "$work/source" -B "$work/native" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_C_COMPILER=clang-20 \
  > "$work/results/native-configure.log"
cmake --build "$work/native" -j8 > "$work/results/native-build.log"

cmake -S "$work/source" -B "$work/guest" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_C_COMPILER="$devkit/bin/x86_64-linux-gnu-clang" \
  -DCMAKE_C_FLAGS="--sysroot=$devkit/x86_64/sysroot -O2" \
  -DCMAKE_EXE_LINKER_FLAGS="--sysroot=$devkit/x86_64/sysroot" \
  -DCMAKE_SHARED_LINKER_FLAGS="--sysroot=$devkit/x86_64/sysroot" \
  > "$work/results/guest-configure.log"
cmake --build "$work/guest" -j8 > "$work/results/guest-build.log"

"$(dirname "$0")/RunSuite.sh" "$work/source" \
  "$work/native/md2html/md2html" "$work/results/native-test.log"
