#!/usr/bin/env bash
set -euo pipefail

# Resolve every path from this file so the command works from any directory.
evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
vcpkg=$repo_root/vcpkg/vcpkg
tool_ports=$repo_root/vcpkg-overlay/ports-tools
triplets=$repo_root/vcpkg-overlay/triplets
triplet=${VCPKG_DEFAULT_TRIPLET:-arm64-linux}
source "$evaluations_dir/common/install-progress.sh"
source "$evaluations_dir/common/proxy-environment.sh"
normalize_proxy_environment

usage() {
    cat <<'EOF'
Usage: ./evaluations/install-tools.sh [--plain]

Install the native FFmpeg utility, four pinned AE emulators, plus the
instrumented QEMU and Box64 breakdown tools. Existing downloads and binary
packages are reused. This script does not install the Lorelei devkit.

Environment:
  VCPKG_DEFAULT_TRIPLET  Target triplet, default: arm64-linux
  INSTALL_NETWORK_ATTEMPTS  Maximum attempts after network failures, default: 5
EOF
}

plain=false
while (($#)); do
    case $1 in
        --plain) plain=true ;;
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
    "qemu-breakdown-ae:${triplet}"
    "blink-ae:${triplet}"
    "box64-ae:${triplet}"
    "box64-callback-track-ae:${triplet}"
    "fex-ae:${triplet}"
)
package_names=(ffmpeg qemu qemu-breakdown blink box64 box64-callback-track fex)

# An ordinary install accepts an older installed version as satisfying the
# request. Upgrade only packages whose pinned port recipe changed, while
# retaining every package that is already current.
echo "Refresh installed AE tools whose pinned recipe changed"
"$vcpkg" upgrade --no-dry-run \
    "--overlay-ports=$tool_ports" \
    "--overlay-triplets=$triplets"

echo "Install AE tools with triplet: $triplet"
install_progress_init Tools "${#packages[@]}" "$plain"
install_progress_setup
for index in "${!packages[@]}"; do
    args=(install "${packages[$index]}" "--overlay-ports=$tool_ports"
        "--overlay-triplets=$triplets")
    install_progress_run "${package_names[$index]}" "$((index + 1))" \
        "$vcpkg" "${args[@]}" || true
done
install_progress_finish
if ((install_progress_failed)); then
    echo "One or more AE tools failed to install." >&2
    exit 1
fi

# Fail immediately if a port reported success without installing its public tool.
installed=$repo_root/vcpkg/installed/$triplet/tools
declare -A expected=(
    [ffmpeg]="$installed/ffmpeg/ffmpeg"
    [qemu]="$installed/qemu-ae/qemu-x86_64"
    [qemu-breakdown]="$installed/qemu-breakdown-ae/qemu-x86_64"
    [blink]="$installed/blink-ae/blink"
    [box64]="$installed/box64-ae/box64"
    [box64-callback-track]="$installed/box64-callback-track-ae/box64-callback-track"
    [fex]="$installed/fex-ae/FEX"
)
for name in ffmpeg qemu qemu-breakdown blink box64 box64-callback-track fex; do
    [[ -x ${expected[$name]} ]] || {
        echo "Installed package is missing $name: ${expected[$name]}" >&2
        exit 1
    }
done

echo
echo "AE tools are ready:"
for name in ffmpeg qemu qemu-breakdown blink box64 box64-callback-track fex; do
    printf '  %-7s %s\n' "$name" "${expected[$name]}"
done
