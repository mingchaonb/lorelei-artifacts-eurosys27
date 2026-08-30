#!/usr/bin/env bash
set -euo pipefail

common_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cli_root=$(cd "$common_dir/.." && pwd)
repo_root=$(cd "$cli_root/../.." && pwd)
work_root=$repo_root/.work/evaluations/cli-benchmarks
input_dir=$cli_root/_inputs
download_dir=$work_root/download
source_url=https://www.youtube.com/watch?v=c6nXIvXtg_o
yt_dlp=${YT_DLP:-yt-dlp}
prep_ffmpeg=$repo_root/vcpkg/installed/arm64-linux/tools/ffmpeg/ffmpeg
prep_ld=$repo_root/vcpkg/installed/arm64-linux/lib

mkdir -p "$input_dir" "$download_dir"

# Generate one fixed 64 MiB input with a deterministic mixture of repeated and
# pseudo-random blocks. zlib, zstd, and OpenSSL all consume this same file.
python3 "$common_dir/generate-data.py" "$input_dir/data-64m.bin" --size-mib 64

# Input preparation uses the untimed official native FFmpeg tool. Keep it
# separate from the FFmpeg 7.1.5 binaries measured by the workload recipes.
if [[ ! -x $prep_ffmpeg ]]; then
    echo "Missing input-preparation FFmpeg: $prep_ffmpeg" >&2
    echo "Install the official vcpkg ffmpeg port with its CLI and codec features first." >&2
    exit 2
fi

if ! command -v "$yt_dlp" >/dev/null 2>&1 && [[ ! -x $yt_dlp ]]; then
    echo "yt-dlp not found. Install it or set YT_DLP=/absolute/path/to/yt-dlp." >&2
    exit 2
fi

source_media=$download_dir/c6nXIvXtg_o.mkv
source_info=$download_dir/c6nXIvXtg_o.info.json
if [[ ! -s $source_media ]]; then
    if ! "$yt_dlp" --no-playlist --write-info-json --merge-output-format mkv \
        -f '136+140/b[vcodec^=avc1][height<=720]' \
        -o "$download_dir/c6nXIvXtg_o.%(ext)s" "$source_url"; then
        echo "yt-dlp could not download the source. Ubuntu's packaged version may be obsolete." >&2
        echo "Set YT_DLP to a current standalone or virtual-environment installation." >&2
        exit 1
    fi
fi

# Derive a 30-second, 48 kHz stereo PCM input for the three audio encoders.
env LD_LIBRARY_PATH="$prep_ld" "$prep_ffmpeg" -hide_banner -loglevel error -y \
    -ss 60 -t 30 -i "$source_media" -vn -ac 2 -ar 48000 -c:a pcm_s16le \
    "$input_dir/audio-30s.wav"

# Derive a bounded 10-second 640-pixel-wide YUV420P stream for libx264. Y4M
# avoids including source decoding in the measured encoder workload.
env LD_LIBRARY_PATH="$prep_ld" "$prep_ffmpeg" -hide_banner -loglevel error -y \
    -ss 60 -t 10 -i "$source_media" -an -vf 'scale=640:-2,fps=30' \
    -pix_fmt yuv420p -f yuv4mpegpipe "$input_dir/video-10s-640.y4m"

[[ -s $input_dir/audio-30s.wav ]] || { echo "Audio input preparation produced no data" >&2; exit 1; }
[[ -s $input_dir/video-10s-640.y4m ]] || { echo "Video input preparation produced no data" >&2; exit 1; }
video_frames=$(grep -ao 'FRAME' "$input_dir/video-10s-640.y4m" | wc -l)
[[ $video_frames == 300 ]] || { echo "Expected 300 Y4M frames, found $video_frames" >&2; exit 1; }

python3 - "$input_dir" "$source_media" "$source_info" <<'PY'
import hashlib
import json
import pathlib
import sys

input_dir = pathlib.Path(sys.argv[1])
paths = [pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])]
paths += [input_dir / "data-64m.bin", input_dir / "audio-30s.wav", input_dir / "video-10s-640.y4m"]
items = []
for path in paths:
    data = path.read_bytes()
    items.append({"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
manifest = {
    "schema_version": 1,
    "source_url": "https://www.youtube.com/watch?v=c6nXIvXtg_o",
    "audio_excerpt": {"start_seconds": 60, "duration_seconds": 30, "format": "PCM S16LE, 48 kHz, stereo"},
    "video_excerpt": {"start_seconds": 60, "duration_seconds": 10, "format": "YUV4MPEG2, 640 pixels wide, 30 fps, YUV420P"},
    "files": items,
}
(input_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(manifest, indent=2, ensure_ascii=False))
PY

echo "Prepared inputs: $input_dir"
