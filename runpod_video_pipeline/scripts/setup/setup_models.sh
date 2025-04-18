#!/bin/bash

# NOTE: As of April 2024
# This script handles model file verification and download, but there are a few things to note:
# 1. The model files might appear as "missing" even when they are present due to path differences
# 2. If you get errors about missing files, manually check:
#    - /workspace/models/Wan2.1-T2V-1.3B/ for the model files
#    - Specifically look for:
#      * models_t5_umt5-xxl-enc-bf16.pth (T5 model)
#      * Wan2.1_VAE.pth (VAE)
#      * diffusion_pytorch_model.safetensors (Diffusion)
#      * google/umt5-xxl/tokenizer.json (Tokenizer)
# 3. After setup completes, you need to:
#    a) Clone the inference code: git clone https://github.com/Wan-Video/Wan2.1
#    b) Install dependencies in the Wan2.1 directory:
#       cd Wan2.1
#       poetry install
#    c) For image-to-video generation:
#       poetry run python generate.py --task i2v-1.3B --size 480x832 --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B --image_path your_image.jpg

set -e

NETWORK_VOLUME="/workspace"
MODEL_DIR="$NETWORK_VOLUME/models/Wan2.1-T2V-1.3B"
LOG_FILE="$NETWORK_VOLUME/models/model_setup.log"

mkdir -p "$(dirname "$LOG_FILE")"

# Simple function to check if files exist
verify_files() {
    echo "Verifying model files..." | tee -a "$LOG_FILE"
    
    # Find any files that match our patterns
    local missing=0
    
    # Check for T5 model (either the pth or safetensors)
    if ! find "$MODEL_DIR" -type f \( -name "*t5*.pth" -o -name "*t5*.safetensors" \) | grep -q .; then
        echo "× Missing T5 model" | tee -a "$LOG_FILE"
        missing=1
    fi
    
    # Check for VAE
    if ! find "$MODEL_DIR" -type f \( -name "*vae*.pth" -o -name "*VAE*.pth" -o -name "*vae*.safetensors" \) | grep -q .; then
        echo "× Missing VAE model" | tee -a "$LOG_FILE"
        missing=1
    fi
    
    # Check for tokenizer files
    if ! find "$MODEL_DIR" -type f \( -name "tokenizer*.json" -o -name "spiece.model" \) | grep -q .; then
        echo "× Missing tokenizer" | tee -a "$LOG_FILE"
        missing=1
    fi
    
    # Check for diffusion model
    if ! find "$MODEL_DIR" -type f -name "*diffusion*.safetensors" | grep -q .; then
        echo "× Missing diffusion model" | tee -a "$LOG_FILE"
        missing=1
    fi
    
    if [ $missing -eq 0 ]; then
        echo "✓ All required files found" | tee -a "$LOG_FILE"
        return 0
    fi
    return 1
}

# Download everything if needed
download_model() {
    mkdir -p "$MODEL_DIR"
    export HF_HUB_ENABLE_HF_TRANSFER=1
    
    echo "Downloading model files..." | tee -a "$LOG_FILE"
    if ! HUGGINGFACE_HUB_CACHE=/workspace/cache/huggingface \
         poetry run huggingface-cli download --resume-download \
         --local-dir-use-symlinks False \
         Wan-AI/Wan2.1-T2V-1.3B \
         --local-dir "$MODEL_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        echo "Download failed" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Main process
if verify_files; then
    echo "All required files already present" | tee -a "$LOG_FILE"
    exit 0
fi

echo "Some files missing, downloading..." | tee -a "$LOG_FILE"
download_model

if ! verify_files; then
    echo "Failed to download all required files" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Setup completed successfully" | tee -a "$LOG_FILE"