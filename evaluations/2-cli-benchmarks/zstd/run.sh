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
args=(-q -f -T1 -3)
for _ in $(seq 1 100); do
    args+=("$input")
done
args+=(-o '{output}')

cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_cli" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_cli" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" \
    BOX64_EMULATED_LIBS=libzstd.so.1 \
    BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_cli" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

env LD_LIBRARY_PATH="$native_ld" python3 - "$native_cli" "$input" "$result_dir" <<'PY'
import hashlib
import pathlib
import subprocess
import sys

zstd, input_name, result_name = sys.argv[1:]
outputs = sorted((pathlib.Path(result_name) / "outputs").glob("*/run-*"))
if not outputs:
    raise SystemExit("no completed zstd outputs found")
compressed_hashes = {hashlib.sha256(path.read_bytes()).digest() for path in outputs}
if len(compressed_hashes) != 1:
    raise SystemExit("completed zstd outputs are not byte-identical")
source = pathlib.Path(input_name).read_bytes()
expected = hashlib.sha256()
for _ in range(100):
    expected.update(source)
actual = hashlib.sha256()
process = subprocess.Popen([zstd, "-q", "-d", "-c", str(outputs[0])], stdout=subprocess.PIPE)
assert process.stdout is not None
for chunk in iter(lambda: process.stdout.read(1024 * 1024), b""):
    actual.update(chunk)
if process.wait() != 0 or actual.digest() != expected.digest():
    raise SystemExit(f"decompressed checksum mismatch: {outputs[0]}")
PY
printf 'input_repetitions=100\nvalidation=all completed outputs are byte-identical and a representative decompresses to one hundred copies of the input\n' >"$result_dir/validation.txt"
echo "Evidence: $result_dir"
