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

state=$repo_root/.work/evaluations/openssl
port=$repo_root/vcpkg-overlay/ports/openssl
native_prefix=$state/installed/native/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae
native_cli=$native_prefix/bin/openssl
guest_cli=$guest_prefix/bin/openssl
thunk_root=$state/thunks
crypto_thunk=$thunk_root/crypto
ssl_thunk=$thunk_root/ssl
libc_thunk=$thunk_root/libc-shim
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || true)

prepare_packages() {
    env LORELEI_DEVKIT="$devkit" "$repo_root/evaluations/1-libs/openssl/run.sh" --install-only
}

generate_thunks() {
    local guest_undefined=$thunk_root/guest-undefined.txt
    local library name manifest_dir symbols host_library audit_dir
    mkdir -p "$thunk_root"
    "$nm_tool" -D --undefined-only --just-symbol-name "$guest_cli" \
        | sed 's/@.*//' | sort -u >"$guest_undefined"

    for library in crypto ssl; do
        name=$library
        manifest_dir=$port/lorelei/$library
        host_library=$(find "$native_prefix/lib" -maxdepth 1 -type f -name "lib$library.so.*" | sort | head -1)
        [[ -n $host_library ]] || { echo "Missing OpenSSL host DSO: lib$library" >&2; exit 2; }
        audit_dir=$thunk_root/audit/$library
        mkdir -p "$audit_dir"
        "$nm_tool" -D --defined-only --format=posix "$host_library" \
            | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' \
            | sort -u >"$audit_dir/functions.txt"
        comm -12 "$guest_undefined" "$audit_dir/functions.txt" >"$audit_dir/used-functions.txt"
        {
            echo '[Function]'
            cat "$audit_dir/used-functions.txt"
        } >"$audit_dir/Symbols.conf"
        [[ -s $audit_dir/used-functions.txt ]] || { echo "No OpenSSL CLI imports found in lib$library" >&2; exit 2; }
        "$devkit/bin/LoreMakeThunk.py" --name "$name" --out "$thunk_root/$name" \
            --lib "$host_library" --symbols "$audit_dir/Symbols.conf" \
            --desc "$port/lorelei/Desc.h" \
            --manifest-host "$manifest_dir/Manifest_host.cpp" \
            --manifest-guest "$manifest_dir/Manifest_guest.cpp" \
            --devkit "$devkit" --keep-intermediates -- \
            -I"$native_prefix/include" -I"$port/lorelei/include"
    done

    local host_libc
    host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
    "$devkit/bin/LoreMakeThunk.py" --name c-shim --out "$libc_thunk" \
        --lib "$host_libc" --soname libc-shim.so \
        --symbols "$port/lorelei/libc-shim/Symbols.conf" \
        --desc "$port/lorelei/libc-shim/Desc.h" \
        --manifest-host "$port/lorelei/libc-shim/Manifest_host.cpp" \
        --manifest-guest "$port/lorelei/libc-shim/Manifest_guest.cpp" \
        --devkit "$devkit" --keep-intermediates -- \
        -D_GNU_SOURCE -I"$port/lorelei/include"
    ln -sf "$host_libc" "$libc_thunk/libc-shim.so"
}

if [[ ! -x $native_cli || ! -x $guest_cli ]]; then
    prepare_packages
fi
[[ -n $nm_tool ]] || { echo "llvm-nm is required to generate the OpenSSL thunk" >&2; exit 2; }
if [[ ! -f $crypto_thunk/libcrypto_HTL.so || ! -f $crypto_thunk/x86_64/libcrypto.so.3 \
      || ! -f $ssl_thunk/libssl_HTL.so || ! -f $ssl_thunk/x86_64/libssl.so.3 \
      || ! -f $libc_thunk/x86_64/libc-shim.so ]]; then
    generate_thunks
fi
if $install_only; then
    echo "Installed OpenSSL benchmark prerequisites: $state"
    exit 0
fi

for executable in "$native_cli" "$guest_cli" "$qemu" "$blink" "$box64" "$fex"; do
    cli_require_executable "$executable"
done
[[ -s $input_dir/manifest.json ]] || "$cli_root/_common/prepare-inputs.sh"

cli_begin_result openssl
native_ld=$native_prefix/lib
guest_ld=$guest_prefix/lib:$devkit/x86_64/lib
host_hecate_ld=$devkit/lib:$native_prefix/lib:$crypto_thunk:$ssl_thunk:$libc_thunk
guest_hecate_ld=$devkit/x86_64/lib:$crypto_thunk/x86_64:$ssl_thunk/x86_64:$libc_thunk/x86_64
hecate_preload=$libc_thunk/x86_64/libc-shim.so
speed_seconds=3
speed_bytes=1048576
args=(speed -mr -elapsed -seconds "$speed_seconds" -bytes "$speed_bytes" -evp sha256)

cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_cli" "${args[@]}"
cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_cli" "${args[@]}"
cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

cli_measure qemu-hecate env LD_LIBRARY_PATH="$host_hecate_ld" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_PRELOAD=$hecate_preload" -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_cli" "${args[@]}"
cli_measure blink-hecate env LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" LD_PRELOAD="$hecate_preload" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}"
cli_measure box64-hecate env LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LD_PRELOAD="$hecate_preload" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
cli_measure fex-hecate env LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_PRELOAD=$hecate_preload:LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

python3 - "$result_dir" "$speed_seconds" "$speed_bytes" <<'PY'
import csv
import json
import pathlib
import re
import statistics
import sys

root = pathlib.Path(sys.argv[1])
seconds = int(sys.argv[2])
buffer_bytes = int(sys.argv[3])
pattern = re.compile(r"^\+F:[0-9]+:sha256:([0-9]+(?:\.[0-9]+)?)$", re.MULTILINE)
rows = []
by_lane = {}
for path in sorted((root / "raw").glob("*/run-*.stdout")):
    lane = path.parent.name
    repetition = int(path.stem.split("-")[-1])
    match = pattern.search(path.read_text())
    if not match:
        raise SystemExit(f"missing OpenSSL SHA-256 throughput result in {path}")
    throughput = float(match.group(1))
    rows.append((lane, repetition, throughput))
    by_lane.setdefault(lane, []).append(throughput)

if not rows:
    raise SystemExit("no OpenSSL SHA-256 throughput results found")

with (root / "throughput.tsv").open("w", newline="") as stream:
    writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
    writer.writerow(["lane", "repetition", "bytes_per_second"])
    writer.writerows(rows)

summary = {
    "schema_version": 1,
    "metric": "SHA-256 throughput",
    "unit": "bytes_per_second",
    "speed_seconds": seconds,
    "buffer_bytes": buffer_bytes,
    "lanes": {},
    "hecate_speedup_over_pure_emulation": {},
}
for lane, values in sorted(by_lane.items()):
    summary["lanes"][lane] = {
        "samples": len(values),
        "minimum": min(values),
        "median": statistics.median(values),
        "maximum": max(values),
        "mean": statistics.fmean(values),
    }

for emulator in ("qemu", "blink", "box64", "fex"):
    hecate = f"{emulator}-hecate"
    if emulator in summary["lanes"] and hecate in summary["lanes"]:
        pure_median = summary["lanes"][emulator]["median"]
        hecate_median = summary["lanes"][hecate]["median"]
        summary["hecate_speedup_over_pure_emulation"][emulator] = hecate_median / pure_median

native = summary["lanes"].get("native")
if native:
    native_median = native["median"]
    summary["fraction_of_native"] = {
        lane: values["median"] / native_median
        for lane, values in summary["lanes"].items()
        if lane.endswith("-hecate")
    }

(root / "throughput-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
printf 'algorithm=SHA-256\nmetric=throughput_bytes_per_second\nseconds=%s\nbytes=%s\nvalidation=every run emitted an OpenSSL machine-readable throughput result\n' \
    "$speed_seconds" "$speed_bytes" >"$result_dir/validation.txt"
echo "Evidence: $result_dir"
