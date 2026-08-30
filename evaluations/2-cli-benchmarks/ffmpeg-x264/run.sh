#!/usr/bin/env bash
set -euo pipefail

workload_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$workload_dir/../_common/common.sh"
source "$workload_dir/../_common/ffmpeg.sh"
workload_options=("$@")
ffmpeg_workload_main ffmpeg-x264 video-10s-640.y4m .mkv h264 \
    -map 0:v:0 -an -c:v libx264 -preset medium -crf 23 -threads 1 -f matroska
