#!/bin/bash

# Wrap the entire script in a function to use return instead of exit
main() {
    # Load environment variables from .env if it exists
    if [[ -f .env ]]; then
        echo "Loading environment variables from .env..."
        source .env || { echo "Error: Failed to load .env file"; return 1; }
    fi

    # Activate Wan2.1 environment if not already activated
    if [[ "$VIRTUAL_ENV" != *"/workspace/Wan2.1/.venv"* ]]; then
        if [[ -f /workspace/Wan2.1/.venv/bin/activate ]]; then
            source /workspace/Wan2.1/.venv/bin/activate || { echo "Error: Failed to activate virtual environment"; return 1; }
        else
            echo "Warning: Wan2.1 virtual environment not found at /workspace/Wan2.1/.venv"
        fi
    fi

    # Default values
    SIZE="480*832"
    TASK="i2v-1.3B"
    FRAME_NUM=16
    UPLOAD_TO_S3=false
    TEMP_DIR="/tmp/wan_video_temp"
    WAN_DIR="/workspace/Wan2.1"

    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR" || { echo "Error: Failed to create temp directory"; return 1; }

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
                return 1
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
        echo "Usage: $0 --image <image_path> --prompt <text> [options]"
        echo ""
        echo "Required arguments:"
        echo "  --image <path>     Path to input image (required)"
        echo "  --prompt <text>    Prompt to guide video generation (required)"
        echo ""
        echo "Optional arguments:"
        echo "  --frames <number>  Number of frames to generate (default: 50)"
        echo "  --size <size>      Video size in format WIDTHxHEIGHT (default: 480*832)"
        echo "  --upload-to-s3     Upload video to S3 (default: false)"
        echo "  -h, --help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 --image input.jpg --prompt 'zooming into the sunset'"
        echo "  $0 --image input.jpg --prompt 'zooming into the sunset' --frames 80"
        echo "  $0 --image input.jpg --prompt 'zooming into the sunset' --size 832*480"
        return 1
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
                return $?
                ;;
            *)
                echo "Unknown parameter: $1"
                show_help
                return 1
                ;;
        esac
    done

    # Check for required parameters
    if [ -z "$IMAGE" ]; then
        echo "Error: --image parameter is required"
        show_help
        return 1
    fi

    if [ -z "$PROMPT" ]; then
        echo "Error: --prompt parameter is required"
        show_help
        return 1
    fi

    # Check if image exists
    if [ ! -f "$IMAGE" ] && [[ ! "$IMAGE" =~ ^https?:// ]]; then
        echo "Error: Image file '$IMAGE' not found and not a URL"
        return 1
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
    if ! (cd "$WAN_DIR" && nohup python generate.py \
        --task i2v-1.3B \
        --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
        --size "$SIZE" \
        --frame_num "$FRAMES" \
        --image "$IMAGE" \
        --prompt "$PROMPT" \
        > "$TEMP_DIR/video_generation.log" 2>&1 &)
    then
        echo "Error: Failed to start video generation"
        return 1
    fi

    # Store the process ID
    PID=$!

    # Wait for the process to complete
    wait $PID || {
        echo "Error: Video generation process failed"
        echo "Check $TEMP_DIR/video_generation.log for details"
        return 1
    }

    # Ring bell once for video completion
    "$(dirname "$0")/../utils/notify.sh" 1 || echo "Warning: Failed to send notification"

    # Upload to S3 if requested
    if [[ "$UPLOAD_TO_S3" = true ]]; then
        echo "Uploading to S3..."
        if [[ "$TASK" == *"t2v"* ]]; then
            OUTPUT_DIR="$WAN_DIR/outputs/t2v"
        else
            OUTPUT_DIR="$WAN_DIR/outputs/i2v"
        fi
        if ! "$(dirname "$0")/upload_s3.sh" "$OUTPUT_DIR"; then
            echo "Error: Failed to upload to S3"
            return 1
        fi
    fi
}

# Run the main function and capture its return value
main "$@"
exit $? 