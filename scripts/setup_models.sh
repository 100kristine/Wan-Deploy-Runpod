#!/bin/bash
set -e  # Exit on any error

# Check if we're in local test mode
if [ "$LOCAL_TEST" = "true" ]; then
    NETWORK_VOLUME="./local_test_models"
    MODEL_DIR="$NETWORK_VOLUME/Wan2.1-T2V-1.3B"
    echo "Running in local test mode - using dummy model files"
else
    NETWORK_VOLUME="/workspace"
    MODEL_DIR="$NETWORK_VOLUME/models/Wan2.1-T2V-1.3B"
fi

# Create log directory
mkdir -p "$(dirname "$NETWORK_VOLUME/models/model_setup.log")"
LOG_FILE="$NETWORK_VOLUME/models/model_setup.log"

echo "Step 2: Model Storage Setup" | tee -a "$LOG_FILE"

# Function to check if a specific model component exists and is valid
check_model_component() {
    local component=$1
    if [ ! -d "$MODEL_DIR/$component" ] || [ -z "$(ls -A $MODEL_DIR/$component 2>/dev/null)" ]; then
        echo "false"
    else
        echo "true"
    fi
}

# Function to download model files if needed
download_model_files() {
    local temp_dir="/tmp/wan_model_download"
    mkdir -p "$MODEL_DIR"
    
    # Define required components
    local components=("t5_tokenizer" "t5_checkpoint" "vae_checkpoint" "clip_checkpoint")
    local missing_components=()
    
    # Check which components are missing
    for component in "${components[@]}"; do
        if [ "$(check_model_component $component)" = "false" ]; then
            missing_components+=($component)
            echo "Missing component: $component" | tee -a "$LOG_FILE"
        else
            echo "Component already exists: $component" | tee -a "$LOG_FILE"
        fi
    done
    
    # If any components are missing, download them
    if [ ${#missing_components[@]} -gt 0 ]; then
        echo "Downloading missing model components..." | tee -a "$LOG_FILE"
        mkdir -p "$temp_dir"
        
        # Download to temporary directory - using 1.3B model
        poetry run huggingface-cli download Wan-AI/Wan2.1-T2V-1.3B --local-dir "$temp_dir"
        
        # Move only missing components
        for component in "${missing_components[@]}"; do
            if [ -d "$temp_dir/$component" ]; then
                echo "Moving $component to final location..." | tee -a "$LOG_FILE"
                rm -rf "$MODEL_DIR/$component" 2>/dev/null || true
                mv "$temp_dir/$component" "$MODEL_DIR/"
            fi
        done
        
        # Cleanup
        rm -rf "$temp_dir"
    else
        echo "All components are already present" | tee -a "$LOG_FILE"
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
    local missing=0
    
    echo "Verifying model files..." | tee -a "$LOG_FILE"
    for file in "${required_files[@]}"; do
        if [ "$(check_model_component $file)" = "false" ]; then
            echo "× Missing or empty required model component: $file" | tee -a "$LOG_FILE"
            missing=1
        else
            echo "✓ Found model component: $file" | tee -a "$LOG_FILE"
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo "Some components are missing or empty. Will attempt to download them." | tee -a "$LOG_FILE"
        return 1
    fi
    
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

# Main process: verify, download missing, verify again
while true; do
    if verify_models; then
        break
    fi
    
    if [ "$LOCAL_TEST" = "true" ]; then
        create_dummy_files
    else
        download_model_files
    fi
    
    # Break if we've downloaded everything but verification still fails
    # This prevents infinite loops if there's a persistent issue
    if ! verify_models; then
        echo "Warning: Some model files are still missing after download attempt." | tee -a "$LOG_FILE"
        echo "You may need to manually verify the model files or retry the setup." | tee -a "$LOG_FILE"
        break
    fi
done

# Test model loading
if ! test_model_loading; then
    echo "× Model loading test failed" | tee -a "$LOG_FILE"
    echo "Warning: Model files exist but loading test failed. You may need to manually verify the model files." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Model storage setup complete! 🎉" | tee -a "$LOG_FILE" 