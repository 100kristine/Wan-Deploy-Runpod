#!/bin/bash
set -e

# Business Logic Goals:
# 1. Simple commands (wanv/wanh) that work from /workspace
# 2. Accept image URLs directly
# 3. Auto-upload to S3 when done
# 4. Source env vars from top-level .env
# 5. Maintain core video functionality

# First, determine the script's location and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="/workspace"

# Source environment variables from workspace root .env
if [[ -f "${WORKSPACE_ROOT}/.env" ]]; then
    set -a
    source "${WORKSPACE_ROOT}/.env"
    set +a
fi

# Activate Wan2.1 environment if it exists
if [[ -f "/workspace/Wan2.1/.venv/bin/activate" ]]; then
    source /workspace/Wan2.1/.venv/bin/activate
fi

# Function to create aliases
setup_wan_aliases() {
    # Vertical video from URL
    alias wanv='function _wanv() {
        cd "${WORKSPACE_ROOT}" && \
        "${SCRIPT_DIR}/video_small.sh" --image "$1" --size "480*832" --frames "${2:-80}" --prompt "${3:-moving}" --upload-to-s3 true
    }; _wanv'

    # Horizontal video from URL
    alias wanh='function _wanh() {
        cd "${WORKSPACE_ROOT}" && \
        "${SCRIPT_DIR}/video_small.sh" --image "$1" --size "832*480" --frames "${2:-80}" --prompt "${3:-moving}" --upload-to-s3 true
    }; _wanh'

    # Text to video
    alias want='function _want() {
        cd "${WORKSPACE_ROOT}" && \
        "${SCRIPT_DIR}/video_small.sh" --task "t2v-1.3B" --prompt "$1" --frames "${2:-80}" --size "480*832" --upload-to-s3 true
    }; _want'
}

# Set up the aliases
setup_wan_aliases

# Print usage instructions
echo "✓ Wan shortcuts are now available:"
echo "  wanv <image_url> [frames] [prompt]  - Generate vertical video"
echo "  wanh <image_url> [frames] [prompt]  - Generate horizontal video"
echo "  want <prompt> [frames]              - Generate text-to-video"
echo ""
echo "Examples:"
echo "  wanv https://example.com/image.jpg"
echo "  wanh https://example.com/image.jpg 120 'zoom out slowly'"
echo "  want 'walking in the rain' 60" 