#!/usr/bin/env bash
set -euo pipefail

workload_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$workload_dir/../_common/common.sh"
source "$workload_dir/../_common/ffmpeg.sh"
workload_options=("$@")
ffmpeg_workload_main ffmpeg-fdk-aac audio-30s.wav .aac aac \
    -map 0:a:0 -c:a libfdk_aac -b:a 192k -threads 1 -f adts
