#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
devkit=${DEVKIT:-"$root/build/install"}
archive="$base/ae-libs/libidn-1.43.tar.gz"
work=${WORK:-"$root/build/ae-libidn"}

rm -rf "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/results" "$work/dump"
tar -xzf "$archive" -C "$work/source" --strip-components=1

if rg -n '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' "$work/source/lib" \
  | rg -v '/(cdefs|attribute)\.h:' > "$work/dump/production-setjmp.txt"; then
  echo "production non-local jump found" >&2
  exit 2
fi

(cd "$work/native" && CC=clang-20 "$work/source/configure" \
  --disable-static --enable-shared --disable-doc \
  > "$work/results/native-configure.log" 2>&1)
(cd "$work/native" && bear --output compile_commands.json -- make -j8 check \
  > "$work/results/native-test.log" 2>&1)

(cd "$work/guest" && \
  CC="$devkit/bin/x86_64-linux-gnu-clang" \
  CFLAGS="--sysroot=$devkit/x86_64/sysroot -O2" \
  LDFLAGS="--sysroot=$devkit/x86_64/sysroot" \
  "$work/source/configure" --host=x86_64-linux-gnu \
  --disable-static --enable-shared --disable-doc \
  > "$work/results/guest-configure.log" 2>&1)
(cd "$work/guest" && make -j8 check TESTS= \
  > "$work/results/guest-build.log" 2>&1)

tail -25 "$work/results/native-test.log"
