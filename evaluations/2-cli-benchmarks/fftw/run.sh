#!/usr/bin/env bash
set -euo pipefail

workload_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$workload_dir/../_common/common.sh"
cli_common_init "$workload_dir"
set +e
cli_parse_options "$@"
status=$?
set -e
if [[ $status != 0 ]]; then
    if [[ $status == 64 ]]; then
        echo "Usage: $0 [--reference] [--install-only] [--lanes comma,separated,names]"
        exit 0
    fi
    exit "$status"
fi

state=$repo_root/.work/evaluations/fftw3
native_prefix=$state/installed/host/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae
thunk=$state/thunks/fftw3
native_bench=$native_prefix/tools/fftw3/upstream-tests/build/bench
guest_bench=$guest_prefix/tools/fftw3/upstream-tests/build/bench

if [[ ! -x $native_bench || ! -x $guest_bench || ! -f $thunk/libfftw3_HTL.so || ! -f $thunk/x86_64/libfftw3.so ]]; then
    env LORELEI_DEVKIT="$devkit" "$repo_root/evaluations/1-libs/fftw3/run.sh" --install-only
fi
if $install_only; then
    echo "Installed FFTW benchmark prerequisites: $state"
    exit 0
fi

for executable in "$native_bench" "$guest_bench" "$qemu" "$blink" "$box64" "$fex"; do
    cli_require_executable "$executable"
done
cli_begin_result fftw
native_ld=$native_prefix/lib
guest_ld=$guest_prefix/lib:$devkit/x86_64/lib
host_hecate_ld=$devkit/lib:$native_prefix/lib:$thunk
guest_hecate_ld=$devkit/x86_64/lib:$thunk/x86_64
args=(-s 3072x3072)

cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_bench" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_bench" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_bench" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_bench" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_bench" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_bench" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_bench" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_bench" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_bench" "${args[@]}"

python3 - "$result_dir" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for summary_name in root.glob("*.json"):
    summary = json.loads(summary_name.read_text())
    if summary.get("status") != "pass":
        continue
    lane = summary["lane"]
    outputs = sorted((root / "raw" / lane).glob("run-*.stdout"))
    if len(outputs) != summary["repetitions_requested"]:
        raise SystemExit(f"missing FFTW stdout for {lane}")
    for output in outputs:
        if not output.read_text(errors="replace").startswith("Problem: 3072x3072, setup:"):
            raise SystemExit(f"missing FFTW report: {output}")
PY
printf 'problem=3072x3072\nvalidation=every completed run emitted the upstream FFTW benchmark report\n' >"$result_dir/validation.txt"
echo "Evidence: $result_dir"
