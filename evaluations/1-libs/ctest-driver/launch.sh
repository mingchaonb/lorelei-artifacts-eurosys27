#!/usr/bin/env bash
set -euo pipefail

mode=$1
shift
case $mode in
  native)
    exec env LD_LIBRARY_PATH="${NATIVE_LIBRARY_PATH:?}" "$@"
    ;;
  hecate)
    exec env LD_LIBRARY_PATH="${HECATE_HOST_LIBRARY_PATH:?}" "${QEMU:?}" -L "${GUEST_SYSROOT:?}" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=${HECATE_GUEST_LIBRARY_PATH:?}" "$@"
    ;;
  *)
    echo "Unknown CTest execution mode: $mode" >&2
    exit 2
    ;;
esac
