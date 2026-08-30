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
[[ -s $input_dir/manifest.json ]] || "$cli_root/_common/prepare-inputs.sh"

cli_begin_result fftw
native_ld=$native_prefix/lib
guest_ld=$guest_prefix/lib:$devkit/x86_64/lib
host_hecate_ld=$devkit/lib:$native_prefix/lib:$thunk
guest_hecate_ld=$devkit/x86_64/lib:$thunk/x86_64
args=(-s 1024x1024)

cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_bench" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_bench" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" -j "$guest_bench" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_bench" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_bench" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_bench" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" -j "$guest_bench" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_bench" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_bench" "${args[@]}"

for output in "$result_dir"/raw/*/run-*.stdout; do
    grep -q '^Problem: 1024x1024, setup:' "$output" || { echo "Missing FFTW report: $output" >&2; exit 1; }
done
printf 'problem=1024x1024\nvalidation=every run emitted the upstream FFTW benchmark report\n' >"$result_dir/validation.txt"
echo "Evidence: $result_dir"
