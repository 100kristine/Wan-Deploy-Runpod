#!/bin/bash
set -e

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
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Available sizes:"
    echo "  vertical, v    -> 480*832"
    echo "  horizontal, h  -> 832*480"
    echo ""
    echo "Available tasks: i2v-1.3B, t2v-1.3B"
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
    echo "Error: Image-to-video requires an image path"
    show_help
    exit 1
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