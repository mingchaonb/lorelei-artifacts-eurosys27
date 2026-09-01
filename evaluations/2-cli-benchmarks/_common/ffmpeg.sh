#!/usr/bin/env bash

# Run one installed FFmpeg encoder through the common native, emulator, and
# Hecate lanes. Workload scripts provide only the input and encoder arguments.
ffmpeg_workload_main() {
    local workload=$1
    local input_name=$2
    local output_suffix=$3
    local expected_codec=$4
    shift 4
    local -a ffmpeg_args=("$@")
    cli_common_init "$workload_dir"
    set +e
    cli_parse_options "${workload_options[@]}"
    local status=$?
    set -e
    if [[ $status != 0 ]]; then
        if [[ $status == 64 ]]; then
            echo "Usage: $0 [--reference] [--install-only] [--lanes comma,separated,names]"
            return 0
        fi
        return "$status"
    fi

    local state=$repo_root/.work/evaluations/ffmpeg
    local native_prefix=$state/installed/native/arm64-linux-ae
    local guest_prefix=$state/installed/guest/x64-linux-ae
    local hecate_prefix=$state/installed/hecate/arm64-linux-ae
    local pack=$state/thunks/pack
    local native_cli=$native_prefix/bin/ffmpeg
    local guest_cli=$guest_prefix/bin/ffmpeg
    local native_probe=$native_prefix/bin/ffprobe

    if [[ ! -x $native_cli || ! -x $guest_cli || ! -x $native_probe || ! -f $pack/libavcodec_HTL.so || ! -f $pack/x86_64/libavcodec.so ]]; then
        env LORELEI_DEVKIT="$devkit" "$repo_root/evaluations/1-libs/ffmpeg/run.sh" --install-only
    fi
    if $install_only; then
        echo "Installed FFmpeg benchmark prerequisites: $state"
        return 0
    fi

    local executable
    for executable in "$native_cli" "$guest_cli" "$native_probe" "$qemu" "$blink" "$box64" "$fex"; do
        cli_require_executable "$executable"
    done
    [[ -s $input_dir/$input_name && -s $input_dir/manifest.json ]] || "$cli_root/_common/prepare-inputs.sh"

    cli_begin_result "$workload" --manifest "$input_dir/manifest.json"
    local input=$input_dir/$input_name
    local native_ld=$native_prefix/lib
    local guest_ld=$guest_prefix/lib:$devkit/x86_64/lib
    local host_hecate_ld=$devkit/lib:$hecate_prefix/lib:$pack
    local guest_hecate_ld=$devkit/x86_64/lib:$pack/x86_64
    local box64_hecate_preload=$pack/x86_64/libavcodec.so.61:$pack/x86_64/libavdevice.so.61:$pack/x86_64/libavfilter.so.10:$pack/x86_64/libavformat.so.61:$pack/x86_64/libavutil.so.59:$pack/x86_64/libswresample.so.5:$pack/x86_64/libswscale.so.8
    local host_extension=$devkit/lib/libLoreHostHLRExtension.so
    local guest_extension=$devkit/x86_64/lib/libLoreGuestHLRExtension.so
    local thread_hook=$devkit/lib/libLoreQEMUThreadHook.so
    local -a input_args=()
    if declare -p ffmpeg_input_args &>/dev/null; then
        input_args=("${ffmpeg_input_args[@]}")
    fi
    local -a args=(-hide_banner -loglevel error -nostdin -y "${input_args[@]}" -i "$input" "${ffmpeg_args[@]}" "{output}$output_suffix")

    cli_measure native env LD_LIBRARY_PATH="$native_ld" "$native_cli" "${args[@]}"
    cli_measure qemu "$qemu" -L "$devkit/x86_64/sysroot" -E "LD_LIBRARY_PATH=$guest_ld" "$guest_cli" "${args[@]}"
    cli_measure blink env LD_LIBRARY_PATH="$guest_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}" || true
    cli_measure box64 env LD_LIBRARY_PATH="$devkit/lib" BOX64_LD_LIBRARY_PATH="$guest_ld" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
    cli_measure fex env LD_LIBRARY_PATH="$devkit/lib" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

    cli_measure qemu-hecate env LORELEI_HOST_EXTENSIONS="$host_extension" LD_PRELOAD="$thread_hook" LD_LIBRARY_PATH="$host_hecate_ld" \
        "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 -E LORELEI_GUEST_EXTENSIONS="$guest_extension" -E "LD_LIBRARY_PATH=$guest_hecate_ld" "$guest_cli" "${args[@]}"
    cli_measure blink-hecate env LORELEI_HOST_EXTENSIONS="$host_extension" LORELEI_GUEST_EXTENSIONS="$guest_extension" LD_LIBRARY_PATH="$host_hecate_ld:$guest_hecate_ld" BLINK_OVERLAYS="$devkit/x86_64/sysroot:" "$blink" "$guest_cli" "${args[@]}" || true
    cli_measure box64-hecate env LORELEI_HOST_EXTENSIONS="$host_extension" LORELEI_GUEST_EXTENSIONS="$guest_extension" LD_LIBRARY_PATH="$host_hecate_ld" BOX64_LD_LIBRARY_PATH="$guest_hecate_ld" BOX64_LD_PRELOAD="$box64_hecate_preload" BOX64_LOG=0 BOX64_NOBANNER=1 BOX64_NORCFILES=1 "$box64" "$guest_cli" "${args[@]}"
    cli_measure fex-hecate env LORELEI_HOST_EXTENSIONS="$host_extension" LORELEI_GUEST_EXTENSIONS="$guest_extension" LD_LIBRARY_PATH="$host_hecate_ld" FEX_ROOTFS="$devkit/x86_64/sysroot" FEX_ENV="LD_LIBRARY_PATH=$guest_hecate_ld" FEX_OUTPUTLOG=stderr "$fex" "$guest_cli" "${args[@]}"

    env LD_LIBRARY_PATH="$native_ld" python3 - "$native_probe" "$result_dir" "$output_suffix" "$expected_codec" <<'PY'
import json
import pathlib
import subprocess
import sys

ffprobe, result_name, suffix, expected_codec = sys.argv[1:]
result = pathlib.Path(result_name)
records = []
for summary_path in sorted(result.glob("*.json")):
    summary = json.loads(summary_path.read_text())
    if summary.get("status") != "pass" or not summary.get("lane"):
        continue
    lane = summary["lane"]
    outputs = sorted((result / "outputs" / lane).glob(f"run-*{suffix}"))
    expected_outputs = summary["repetitions_requested"]
    if len(outputs) != expected_outputs:
        raise SystemExit(f"expected {expected_outputs} outputs for {lane}, found {len(outputs)}")
    for output in outputs:
        command = [
            ffprobe, "-v", "error", "-show_entries",
            "stream=codec_name,duration:format=duration,size", "-of", "json", str(output),
        ]
        data = json.loads(subprocess.check_output(command))
        codecs = [stream.get("codec_name") for stream in data.get("streams", [])]
        if expected_codec not in codecs:
            raise SystemExit(f"expected codec {expected_codec} in {output}, found {codecs}")
        duration = float(data["format"]["duration"])
        if duration < 9.0:
            raise SystemExit(f"unexpectedly short output {output}: {duration}")
        records.append({"path": str(output), "bytes": output.stat().st_size, "duration": duration, "codecs": codecs})
(result / "validation.json").write_text(json.dumps(records, indent=2) + "\n")
PY
    echo "Evidence: $result_dir"
}
