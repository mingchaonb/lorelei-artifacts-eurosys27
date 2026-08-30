#!/usr/bin/env bash
set -euo pipefail

# Resolve every path from this file so the command works from any directory.
evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
vcpkg=$repo_root/vcpkg/vcpkg
tool_ports=$repo_root/vcpkg-overlay/ports-tools
triplet=${VCPKG_DEFAULT_TRIPLET:-arm64-linux}

usage() {
    cat <<'EOF'
Usage: ./evaluations/install-tools.sh [--verbose]

Install the native FFmpeg utility and the four pinned AE emulators into the
repository-local vcpkg/installed tree. Existing binary packages are reused.

Environment:
  VCPKG_DEFAULT_TRIPLET  Target triplet, default: arm64-linux
EOF
}

verbose=false
while (($#)); do
    case $1 in
        --verbose) verbose=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[[ -x $vcpkg ]] || {
    echo "Missing repository-local vcpkg executable: $vcpkg" >&2
    echo "Follow vcpkg-overlay/README.md to bootstrap it first." >&2
    exit 2
}
[[ -d $tool_ports ]] || { echo "Missing tool overlay: $tool_ports" >&2; exit 2; }

# This feature set provides the native FFmpeg executable used to prepare and
# validate every codec workload. It intentionally comes from vcpkg's built-in
# port because the library-test overlay contains a different Hecate recipe.
ffmpeg_features='ffmpeg[avcodec,avdevice,avfilter,avformat,fdk-aac,ffmpeg,ffprobe,gpl,mp3lame,nonfree,swresample,swscale,vorbis,x264]'
packages=(
    "${ffmpeg_features}:${triplet}"
    "qemu-ae:${triplet}"
    "blink-ae:${triplet}"
    "box64-ae:${triplet}"
    "fex-ae:${triplet}"
)

args=(install "${packages[@]}" "--overlay-ports=$tool_ports")
$verbose && args+=(--debug)

echo "Install AE tools with triplet: $triplet"
"$vcpkg" "${args[@]}"

# Fail immediately if a port reported success without installing its public tool.
installed=$repo_root/vcpkg/installed/$triplet/tools
declare -A expected=(
    [ffmpeg]="$installed/ffmpeg/ffmpeg"
    [qemu]="$installed/qemu-ae/qemu-x86_64"
    [blink]="$installed/blink-ae/blink"
    [box64]="$installed/box64-ae/box64"
    [fex]="$installed/fex-ae/FEX"
)
for name in ffmpeg qemu blink box64 fex; do
    [[ -x ${expected[$name]} ]] || {
        echo "Installed package is missing $name: ${expected[$name]}" >&2
        exit 1
    }
done

echo
echo "AE tools are ready:"
for name in ffmpeg qemu blink box64 fex; do
    printf '  %-7s %s\n' "$name" "${expected[$name]}"
done
