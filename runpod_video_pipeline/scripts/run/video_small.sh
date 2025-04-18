#!/bin/bash
set -e

# Load environment variables from .env if it exists
if [[ -f .env ]]; then
    echo "Loading environment variables from .env..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Activate Wan2.1 environment if not already activated
if [[ "$VIRTUAL_ENV" != *"/workspace/Wan2.1/.venv"* ]]; then
    source /workspace/Wan2.1/.venv/bin/activate
fi

# Change to Wan2.1 directory
cd /workspace/Wan2.1

# Default values
SIZE="480*832"
TASK="i2v-1.3B"
FRAME_NUM=16
DEFAULT_PROMPT="a person smiling in slow motion"  # Practical default for testing
UPLOAD_TO_S3=false
TEMP_DIR="/tmp/wan_video_temp"

# Create temp directory if it doesn't exist
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"/*
}

# Set up cleanup on script exit
trap cleanup EXIT

# Download image from URL if needed
download_image() {
    local input="$1"
    local temp_file
    
    # Check if input is a URL
    if [[ "$input" =~ ^https?:// ]]; then
        echo "Downloading image from URL..."
        temp_file="$TEMP_DIR/$(basename "$input")"
        if ! curl -sSL "$input" -o "$temp_file"; then
            echo "Error: Failed to download image from URL"
            exit 1
        fi
        echo "✓ Download complete"
        echo "$temp_file"
    else
        # Input is a local file
        echo "$input"
    fi
}

# Resolution shortcuts
get_resolution() {
    local size="$1"
    
    case "$size" in
        "vertical"|"v"|"portrait"|"p")
            echo "480*832"
            ;;
        "horizontal"|"h"|"landscape"|"l")
            echo "832*480"
            ;;
        "480*832"|"832*480")
            echo "$size"
            ;;
        *)
            echo "Error: Invalid size $size. Using default 480*832." >&2
            echo "480*832"
            ;;
    esac
}

# Help message
show_help() {
    echo "Usage: video_small.sh [options] <image_or_prompt>"
    echo "Generate a video using Wan2.1 (1.3B model)"
    echo ""
    echo "Options:"
    echo "  -s, --size     Video size (default: vertical)"
    echo "  -t, --task     Task type (default: i2v-1.3B)"
    echo "  -f, --frames   Number of frames (default: 16)"
    echo "  -p, --prompt   Text prompt for t2v"
    echo "                 (default: '$DEFAULT_PROMPT')"
    echo "  -u, --upload   Upload result to S3 (requires AWS env vars)"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Available sizes:"
    echo "  vertical, v    -> 480*832"
    echo "  horizontal, h  -> 832*480"
    echo ""
    echo "Available tasks: i2v-1.3B, t2v-1.3B"
    echo ""
    echo "Input can be:"
    echo "  - Local file path"
    echo "  - URL (will be downloaded automatically)"
    echo "  - Text prompt (for t2v task)"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--size)
            SIZE=$(get_resolution "$2")
            shift 2
            ;;
        -t|--task)
            if [[ "$2" == *"14B"* ]]; then
                echo "Error: 14B model not installed. Using 1.3B model."
                TASK="${2/14B/1.3B}"
            else
                TASK="$2"
            fi
            shift 2
            ;;
        -f|--frames)
            FRAME_NUM="$2"
            shift 2
            ;;
        -p|--prompt)
            PROMPT="$2"
            shift 2
            ;;
        -u|--upload)
            UPLOAD_TO_S3=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ "$TASK" == *"t2v"* ]]; then
                PROMPT="$1"
            else
                IMAGE="$1"
            fi
            shift
            ;;
    esac
done

# Set default prompt if none provided for t2v
if [[ "$TASK" == *"t2v"* && -z "$PROMPT" ]]; then
    PROMPT="$DEFAULT_PROMPT"
    echo "No prompt provided, using default: $PROMPT"
fi

# Validate input
if [[ "$TASK" == *"i2v"* && -z "$IMAGE" ]]; then
    echo "Error: Image-to-video requires an image path or URL"
    show_help
    exit 1
fi

# Download image if it's a URL
if [[ "$TASK" == *"i2v"* ]]; then
    IMAGE=$(download_image "$IMAGE")
fi

# Run generation
if [[ "$TASK" == *"t2v"* ]]; then
    python generate.py \
        --task "$TASK" \
        --size "$SIZE" \
        --ckpt_dir "/workspace/models/Wan2.1-T2V-1.3B" \
        --prompt "$PROMPT" \
        --frame_num "$FRAME_NUM"
else
    python generate.py \
        --task "$TASK" \
        --size "$SIZE" \
        --ckpt_dir "/workspace/models/Wan2.1-T2V-1.3B" \
        --image "$IMAGE" \
        --frame_num "$FRAME_NUM"
fi

# Ring bell once for video completion
"$(dirname "$0")/../utils/notify.sh" 1

# Upload to S3 if requested
if [[ "$UPLOAD_TO_S3" = true ]]; then
    echo "Uploading to S3..."
    if [[ "$TASK" == *"t2v"* ]]; then
        OUTPUT_DIR="outputs/t2v"
    else
        OUTPUT_DIR="outputs/i2v"
    fi
    "$(dirname "$0")/upload_s3.sh" "$OUTPUT_DIR"
fi 