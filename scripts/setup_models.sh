#!/bin/bash
set -e  # Exit on any error

# Check if we're in local test mode
if [ "$LOCAL_TEST" = "true" ]; then
    NETWORK_VOLUME="./local_test_models"
    MODEL_DIR="$NETWORK_VOLUME/Wan2.1-T2V-14B"
    echo "Running in local test mode - using dummy model files"
else
    NETWORK_VOLUME="/workspace"
    MODEL_DIR="$NETWORK_VOLUME/models/Wan2.1-T2V-14B"
fi

# Create log directory
mkdir -p "$(dirname "$NETWORK_VOLUME/models/model_setup.log")"
LOG_FILE="$NETWORK_VOLUME/models/model_setup.log"

echo "Step 2: Model Storage Setup" | tee -a "$LOG_FILE"

# Function to download model files if needed
download_model_files() {
    if [ ! -d "$MODEL_DIR" ] || [ -z "$(ls -A $MODEL_DIR 2>/dev/null)" ]; then
        echo "Creating model directory..." | tee -a "$LOG_FILE"
        mkdir -p "$MODEL_DIR"
        echo "Downloading model files..." | tee -a "$LOG_FILE"
        poetry run huggingface-cli download Wan-AI/Wan2.1-T2V-14B --local-dir "$MODEL_DIR"
    else
        echo "Model directory already exists and is not empty" | tee -a "$LOG_FILE"
    fi
}

# Function to create dummy model files for local testing
create_dummy_files() {
    echo "Creating dummy model files for testing..." | tee -a "$LOG_FILE"
    mkdir -p "$MODEL_DIR"/{t5_tokenizer,t5_checkpoint,vae_checkpoint,clip_checkpoint}
    echo "dummy_content" > "$MODEL_DIR/t5_tokenizer/dummy.bin"
    echo "dummy_content" > "$MODEL_DIR/t5_checkpoint/dummy.bin"
    echo "dummy_content" > "$MODEL_DIR/vae_checkpoint/dummy.bin"
    echo "dummy_content" > "$MODEL_DIR/clip_checkpoint/dummy.bin"
}

# Function to verify model files
verify_models() {
    local required_files=(
        "t5_tokenizer"
        "t5_checkpoint"
        "vae_checkpoint"
        "clip_checkpoint"
    )
    
    echo "Verifying model files..." | tee -a "$LOG_FILE"
    for file in "${required_files[@]}"; do
        if [ ! -e "$MODEL_DIR/$file" ]; then
            echo "× Missing required model file: $file" | tee -a "$LOG_FILE"
            return 1
        fi
    done
    echo "✓ All required model files present" | tee -a "$LOG_FILE"
    return 0
}

# Function to test model loading
test_model_loading() {
    if [ "$LOCAL_TEST" = "true" ]; then
        echo "Skipping model loading test in local mode" | tee -a "$LOG_FILE"
        return 0
    fi
    
    echo "Testing model loading..." | tee -a "$LOG_FILE"
    if poetry run python -c "
import sys
from pathlib import Path
model_dir = '$MODEL_DIR'
try:
    # Test T5 loading
    from transformers import T5EncoderModel, T5Tokenizer
    t5 = T5EncoderModel.from_pretrained(f'{model_dir}/t5_checkpoint')
    tokenizer = T5Tokenizer.from_pretrained(f'{model_dir}/t5_tokenizer')
    print('✓ T5 loading test successful')
    
    # Test VAE loading (simplified test)
    if not Path(f'{model_dir}/vae_checkpoint').exists():
        raise FileNotFoundError('VAE checkpoint not found')
    print('✓ VAE checkpoint found')
    
    print('✓ Model loading test successful')
except Exception as e:
    print(f'× Model loading failed: {str(e)}')
    sys.exit(1)
" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if network volume is mounted
if [ "$LOCAL_TEST" = "true" ]; then
    mkdir -p "$NETWORK_VOLUME"
else
    if ! mountpoint -q "$NETWORK_VOLUME"; then
        echo "× Network volume not mounted at $NETWORK_VOLUME" | tee -a "$LOG_FILE"
        echo "Please mount the network volume first" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

# Create models directory
mkdir -p "$(dirname "$MODEL_DIR")"

# Download or create model files
if [ "$LOCAL_TEST" = "true" ]; then
    create_dummy_files
else
    download_model_files
fi

# Verify model files
if ! verify_models; then
    echo "Please ensure all model files are present in $MODEL_DIR" | tee -a "$LOG_FILE"
    echo "Required structure:" | tee -a "$LOG_FILE"
    echo "  $MODEL_DIR/" | tee -a "$LOG_FILE"
    echo "  ├── t5_tokenizer/" | tee -a "$LOG_FILE"
    echo "  ├── t5_checkpoint/" | tee -a "$LOG_FILE"
    echo "  ├── vae_checkpoint/" | tee -a "$LOG_FILE"
    echo "  └── clip_checkpoint/" | tee -a "$LOG_FILE"
    exit 1
fi

# Test model loading
if ! test_model_loading; then
    echo "× Model loading test failed" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Model storage setup complete! 🎉" | tee -a "$LOG_FILE" 