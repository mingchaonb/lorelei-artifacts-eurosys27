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

state=$repo_root/.work/evaluations/zlib
native_prefix=$state/installed/native/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae-gcc
hecate_prefix=$state/installed/hecate/arm64-linux-ae
thunk=$state/run/thunks/z
native_upstream=$native_prefix/tools/zlib/upstream-tests
guest_upstream=$guest_prefix/tools/zlib/upstream-tests
native_cli=$native_upstream/minizip
guest_cli=$guest_upstream/minizip

if [[ ! -x $native_cli || ! -x $guest_cli || ! -f $thunk/libz_HTL.so || ! -f $thunk/x86_64/libz.so ]]; then
    env LORELEI_DEVKIT="$devkit" "$repo_root/evaluations/1-libs/zlib/run.sh" --install-only
fi
if $install_only; then
    echo "Installed zlib benchmark prerequisites: $state"
    exit 0
fi

for executable in "$native_cli" "$guest_cli" "$qemu" "$blink" "$box64" "$fex"; do
    cli_require_executable "$executable"
done
[[ -s $input_dir/data-64m.bin ]] || \
    python3 "$cli_root/_common/generate-data.py" "$input_dir/data-64m.bin" --size-mib 64

cli_begin_result zlib
input=$input_dir/data-64m.bin
native_ld=$native_upstream:$native_prefix/lib
guest_ld=$guest_upstream:$guest_prefix/lib:$devkit/x86_64/lib
host_hecate_ld=$devkit/lib:$hecate_prefix/lib:$thunk
guest_hecate_ld=$guest_upstream:$devkit/x86_64/lib:$thunk/x86_64

args=(-9 -o '{output}.zip')
for _ in 1 2 3 4 5; do
    args+=("$input")
done
cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_cli" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_cli" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_cli" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

python3 - "$input" "$result_dir" <<'PY'
import hashlib
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
result = pathlib.Path(sys.argv[2])
expected = hashlib.sha256(source.read_bytes()).hexdigest()
for output in sorted((result / "outputs").glob("*/run-*.zip")):
    with zipfile.ZipFile(output) as archive:
        members = [info for info in archive.infolist() if not info.is_dir()]
        if len(members) != 5:
            raise SystemExit(f"expected five ZIP members: {output}")
        for member in members:
            with archive.open(member) as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            if actual != expected:
                raise SystemExit(f"decompressed checksum mismatch: {output}:{member.filename}")
(result / "validation.txt").write_text(
    f"input_sha256={expected}\ninput_repetitions=5\nvalidation=all completed outputs contain five verified copies of the input\n"
)
PY
echo "Evidence: $result_dir"
