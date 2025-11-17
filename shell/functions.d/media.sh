#!/usr/bin/env bash
# Media conversion functions

# Convert video to MP4 format
videoconvert() {
    local input="$1"
    local output="$2"
    local quality="${3:-veryslow}"

    # Show help
    if [[ "$input" == "-h" || "$input" == "--help" || -z "$input" ]]; then
        cat <<EOF
Usage: videoconvert <input> <output> [quality]

Convert video files to MP4 format using H.264 codec.

Arguments:
  input    - Input video file (any format)
  output   - Output MP4 file
  quality  - Quality preset (default: veryslow)
             Options: ultrafast, fast, medium, slow, veryslow

Examples:
  videoconvert input.mov output.mp4
  videoconvert input.avi output.mp4 fast
EOF
        return 0
    fi

    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg not installed"
        echo "Install: brew install ffmpeg"
        return 1
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file not found: $input"
        return 1
    fi

    if [[ -z "$output" ]]; then
        echo "Error: Output file required"
        return 1
    fi

    echo "Converting: $input -> $output (quality: $quality)"
    ffmpeg -i "$input" -vcodec libx264 -crf 23 -preset "$quality" -acodec aac -b:a 128k -movflags +faststart "$output"
}

# Batch convert videos to MP4
convert_video_to_mp4() {
    if ! command -v ffmpeg &>/dev/null; then
        echo "ffmpeg is required but not installed"
        return 1
    fi

    find . -name '*.mov' -print0 | xargs -0 -I xxx ffmpeg -i xxx -f mp4 -vcodec mpeg4 -qscale 0 xxx.mp4
    find . -iname '*.mov.mp4' -print0 | xargs -0 rename 's/\.mov\.mp4$/\.mp4/i'
    mkdir -p ./oldmovies/
    find . -iname '*.mov' -print0 | xargs -0 -I fff mv fff ./oldmovies/
}
