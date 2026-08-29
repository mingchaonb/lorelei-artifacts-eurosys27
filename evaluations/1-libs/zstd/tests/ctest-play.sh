#!/usr/bin/env bash
set -euo pipefail

mode=$1
suite_dir=$2
upstream=$3
cli=$4
datagen=$5
native_prefix=$6
guest_prefix=$7
hecate_prefix=$8
thunk_dir=$9
recipe_dir=${10}
qemu=${11}
devkit=${12}

cmake -E remove_directory "$suite_dir"
mkdir -p "$suite_dir/tests"
cp -R "$upstream/tests/." "$suite_dir/tests/"
cp -R "$upstream/programs" "$suite_dir/programs"

if [[ $mode == native ]]; then
  cd "$suite_dir"
  EXE_PREFIX= ZSTD_BIN="$cli" DATAGEN_BIN="$datagen" LD_LIBRARY_PATH="$native_prefix/lib" sh ./tests/playTests.sh
else
  sed -i -E 's#^([[:space:]]*)\./(xz|unxz|lzma|unlzma)([[:space:]])#\1$EXE_PREFIX ./\2\3#' "$suite_dir/tests/playTests.sh"
  cd "$suite_dir"
  QEMU="$qemu" DEVKIT="$devkit" GUEST_LIB_DIR="$guest_prefix/lib" LORE_AE_HECATE=1 \
    HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$thunk_dir" \
    EXE_PREFIX="$recipe_dir/QEMUWrapper.sh" ZSTD_BIN="$cli" \
    QEMU_WRAPPER="$recipe_dir/QEMUWrapper.sh" GUEST_DATAGEN="$datagen" \
    DATAGEN_BIN="$recipe_dir/QEMUDataGenWrapper.sh" sh ./tests/playTests.sh
fi
