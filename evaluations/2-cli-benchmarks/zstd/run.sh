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

state=$repo_root/.work/evaluations/zstd
native_prefix=$state/installed/native/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae
hecate_prefix=$state/installed/hecate/arm64-linux-ae
thunk=$state/run/thunks/zstd
native_cli=$native_prefix/tools/zstd/upstream-tests/bin/zstd
guest_cli=$guest_prefix/tools/zstd/upstream-tests/bin/zstd

prepare_library() {
    env LORELEI_DEVKIT="$devkit" "$repo_root/evaluations/1-libs/zstd/run.sh" --install-only
}

if [[ ! -x $native_cli || ! -x $guest_cli || ! -f $thunk/libzstd_HTL.so || ! -f $thunk/x86_64/libzstd.so ]]; then
    prepare_library
fi
if $install_only; then
    echo "Installed zstd benchmark prerequisites: $state"
    exit 0
fi

for executable in "$native_cli" "$guest_cli" "$qemu" "$blink" "$box64" "$fex"; do
    cli_require_executable "$executable"
done
[[ -s $input_dir/data-64m.bin && -s $input_dir/manifest.json ]] || "$cli_root/_common/prepare-inputs.sh"

cli_begin_result zstd
input=$input_dir/data-64m.bin
native_ld=$native_prefix/lib
guest_ld=$guest_prefix/lib:$devkit/x86_64/lib
host_hecate_ld=$devkit/lib:$hecate_prefix/lib:$thunk
guest_hecate_ld=$devkit/x86_64/lib:$thunk/x86_64
args=(-q -f -T1 -3 "$input" -o '{output}')

cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_cli" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_cli" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_cli" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

expected=$(sha256sum "$input" | awk '{print $1}')
for output in "$result_dir"/outputs/*/run-*; do
    actual=$(env LD_LIBRARY_PATH="$native_ld" "$native_cli" -q -d -c "$output" | sha256sum | awk '{print $1}')
    [[ $actual == "$expected" ]] || { echo "Decompressed checksum mismatch: $output" >&2; exit 1; }
done
printf 'input_sha256=%s\nvalidation=all outputs decompress to the input\n' "$expected" >"$result_dir/validation.txt"
echo "Evidence: $result_dir"
