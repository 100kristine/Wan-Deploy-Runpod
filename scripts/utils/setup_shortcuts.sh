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

# Add scripts to PATH
export PATH=\$PATH:/workspace/Wan-Deploy-Runpod/scripts/run" >> "$BASHRC"

# Make sure video_small.sh is executable
chmod +x /workspace/Wan-Deploy-Runpod/scripts/run/video_small.sh

# Source the updated bashrc
source "$BASHRC"

echo "✓ Shortcuts installed! Available commands:
  wanenv     - Activate Wan2.1 environment
  wanv       - Generate vertical video (480*832)
  wanh       - Generate horizontal video (832*480)
  want       - Generate text-to-video (uses default prompt if none provided)
  
Usage examples:
  wanv input.jpg                    # Generate vertical video
  wanh -f 32 input.jpg             # Generate horizontal video with 32 frames
  want 'person walking in slow motion'  # Generate video from text
  want                             # Uses default prompt: 'person smiling in slow motion'" 