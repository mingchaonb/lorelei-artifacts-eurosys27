#!/usr/bin/env bash
set -euo pipefail

workload_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$workload_dir/../_common/common.sh"
source "$workload_dir/../_common/ffmpeg.sh"
workload_options=("$@")
# Seven copies of the 30-second sample keep native execution above 1.5 seconds.
ffmpeg_input_args=(-stream_loop 6)
ffmpeg_workload_main ffmpeg-mp3lame audio-30s.wav .mp3 mp3 \
    -map 0:a:0 -c:a libmp3lame -b:a 192k -threads 1
