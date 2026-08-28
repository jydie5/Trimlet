#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
MEDIA_DIR="$PROJECT_DIR/TestMedia"
FFMPEG="/opt/homebrew/bin/ffmpeg"

if [[ ! -x "$FFMPEG" ]]; then
    FFMPEG="/usr/local/bin/ffmpeg"
fi

if [[ ! -x "$FFMPEG" ]]; then
    echo "FFmpegが見つかりません。"
    exit 1
fi

mkdir -p "$MEDIA_DIR"

"$FFMPEG" \
    -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=1280x720:rate=30" \
    -f lavfi -i "sine=frequency=440:sample_rate=48000" \
    -f lavfi -i "sine=frequency=880:sample_rate=48000" \
    -t 8 \
    -map 0:v:0 -map 1:a:0 -map 2:a:0 \
    -c:v libx264 -g 30 -keyint_min 30 -sc_threshold 0 -pix_fmt yuv420p \
    -c:a aac -b:a 128k \
    -metadata:s:a:0 language=jpn -metadata:s:a:0 handler_name="Main 440 Hz" \
    -metadata:s:a:1 language=eng -metadata:s:a:1 handler_name="Alternate 880 Hz" \
    -movflags +faststart \
    "$MEDIA_DIR/trimlet-sample.mp4"

"$FFMPEG" \
    -hide_banner -loglevel error -y \
    -i "$MEDIA_DIR/trimlet-sample.mp4" \
    -map 0:v:0 -map 0:a \
    -c:v copy \
    -c:a ac3 -b:a 192k \
    -f mpegts \
    "$MEDIA_DIR/trimlet-realistic.m2ts"

if [[ ! -f "$MEDIA_DIR/trimlet-long-5m10s.mp4" ]]; then
    "$FFMPEG" \
        -hide_banner -loglevel error -y \
        -f lavfi -i "testsrc2=size=640x360:rate=30:duration=310" \
        -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=310" \
        -c:v h264_videotoolbox -b:v 1M -g 60 \
        -c:a aac -b:a 96k \
        -movflags +faststart \
        "$MEDIA_DIR/trimlet-long-5m10s.mp4"
fi

echo "$MEDIA_DIR/trimlet-sample.mp4"
echo "$MEDIA_DIR/trimlet-realistic.m2ts"
echo "$MEDIA_DIR/trimlet-long-5m10s.mp4"
