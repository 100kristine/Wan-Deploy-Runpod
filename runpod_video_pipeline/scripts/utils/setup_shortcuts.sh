#!/bin/bash
set -e

# Path to bashrc
BASHRC="/root/.bashrc"

# Add our custom shortcuts
echo "
# Wan2.1 shortcuts
alias wanenv='cd /workspace/Wan2.1 && source .venv/bin/activate'
alias wanv='wanenv && video_small.sh -s vertical'
alias wanh='wanenv && video_small.sh -s horizontal'
alias want='wanenv && video_small.sh -t t2v-1.3B'      # Will use default prompt if none provided
alias wans3='cd /workspace/Wan2.1 && upload_s3.sh'     # Upload to S3 (requires AWS env vars)

# Add scripts to PATH
export PATH=\$PATH:/workspace/Wan-Deploy-Runpod/runpod_video_pipeline/scripts/run" >> "$BASHRC"

# Make scripts executable
chmod +x /workspace/Wan-Deploy-Runpod/runpod_video_pipeline/scripts/run/video_small.sh
chmod +x /workspace/Wan-Deploy-Runpod/runpod_video_pipeline/scripts/run/upload_s3.sh
chmod +x /workspace/Wan-Deploy-Runpod/runpod_video_pipeline/scripts/utils/notify.sh

# Source the updated bashrc
source "$BASHRC"

echo "✓ Shortcuts installed! Available commands:
  wanenv     - Activate Wan2.1 environment
  wanv       - Generate vertical video (480*832)
  wanh       - Generate horizontal video (832*480)
  want       - Generate text-to-video (uses default prompt if none provided)
  wans3      - Upload files/folders to S3
  
Usage examples:
  wanv input.jpg                    # Generate vertical video from local file
  wanv https://example.com/img.jpg  # Generate video from URL
  wanh -f 32 input.jpg             # Generate horizontal video with 32 frames
  want 'person walking in slow motion'  # Generate video from text
  want                             # Uses default prompt: 'person smiling in slow motion'
  
  # S3 Upload examples (after setting AWS env vars):
  wanv -u input.jpg                # Generate and auto-upload to S3
  wans3 outputs/i2v                # Upload entire i2v output folder
  wans3 -p custom/path/ file.mp4   # Upload with custom S3 prefix" 