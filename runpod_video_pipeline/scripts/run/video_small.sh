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
    echo "Usage: $0 --image <image_path> [options]"
    echo ""
    echo "Required arguments:"
    echo "  --image <path>     Path to input image (required)"
    echo ""
    echo "Optional arguments:"
    echo "  --prompt <text>    Prompt to guide video generation (default: 'moving...')"
    echo "  --frames <number>  Number of frames to generate (default: 50)"
    echo "  --size <size>      Video size in format WIDTHxHEIGHT (default: 480*832)"
    echo "  --upload-to-s3     Upload video to S3 (default: false)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --image input.jpg"
    echo "  $0 --image input.jpg --prompt 'zooming into the sunset' --frames 80"
    echo "  $0 --image input.jpg --size 832*480  # Horizontal format"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --frames)
            FRAMES="$2"
            shift 2
            ;;
        --size)
            SIZE="$2"
            shift 2
            ;;
        --upload-to-s3)
            UPLOAD_TO_S3="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            ;;
    esac
done

# Check for required image parameter
if [ -z "$IMAGE" ]; then
    echo "Error: --image parameter is required"
    show_help
fi

# Check for empty prompt
if [ -z "$PROMPT" ]; then
    echo "Error: --prompt parameter cannot be empty"
    exit 1
fi

# Check if image exists
if [ ! -f "$IMAGE" ] && [[ ! "$IMAGE" =~ ^https?:// ]]; then
    echo "Error: Image file '$IMAGE' not found and not a URL"
    exit 1
fi

# Run the generation command
echo "Generating video with settings:"
echo "- Image: $IMAGE"
echo "- Prompt: $PROMPT"
echo "- Frames: $FRAMES"
echo "- Size: $SIZE"
echo "- Upload to S3: $UPLOAD_TO_S3"
echo ""

# Run with nohup and redirect output to a log file
nohup python generate.py \
    --task i2v-1.3B \
    --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
    --size "$SIZE" \
    --frame_num "$FRAMES" \
    --image "$IMAGE" \
    --prompt "$PROMPT" \
    > video_generation.log 2>&1 &

# Store the process ID
PID=$!

# Wait for the process to complete
wait $PID

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