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

# Function to check available space in GB
check_available_space() {
    local path=$1
    local available_kb=$(df -k "$path" | awk 'NR==2 {print $4}')
    echo $((available_kb / 1024 / 1024))
}

# Function to clean up temporary files and cache
cleanup_temp_files() {
    echo "Cleaning up temporary files and cache..." | tee -a "$LOG_FILE"
    rm -rf /dev/shm/wan_model_download
    rm -rf /workspace/cache/huggingface/hub/tmp*
}

# Function to setup cache directory
setup_cache() {
    echo "Setting up cache directory..." | tee -a "$LOG_FILE"
    # Move cache to workspace if it's in root
    if [ -d "/root/.cache/huggingface" ] && [ ! -L "/root/.cache/huggingface" ]; then
        echo "Moving cache to workspace..." | tee -a "$LOG_FILE"
        mkdir -p /workspace/cache
        mv /root/.cache/huggingface /workspace/cache/ 2>/dev/null || true
        rm -rf /root/.cache/huggingface
        ln -s /workspace/cache/huggingface /root/.cache/huggingface
    fi
    
    # Ensure cache directory exists
    mkdir -p /workspace/cache/huggingface
    
    # Ensure symlink exists
    if [ ! -L "/root/.cache/huggingface" ]; then
        ln -s /workspace/cache/huggingface /root/.cache/huggingface
    fi
}

# Function to download model files if needed
download_model_files() {
    local temp_dir="/dev/shm/wan_model_download"
    mkdir -p "$MODEL_DIR"
    
    # Setup cache in workspace
    setup_cache
    
    # Check available space
    local required_space_gb=15  # Adjust this based on 1.3B model size
    local available_space_gb=$(check_available_space "/dev/shm")
    local model_space_gb=$(check_available_space "$NETWORK_VOLUME")
    
    echo "Available space:" | tee -a "$LOG_FILE"
    echo "- /dev/shm (temp): ${available_space_gb}GB" | tee -a "$LOG_FILE"
    echo "- $NETWORK_VOLUME: ${model_space_gb}GB" | tee -a "$LOG_FILE"
    
    if [ "$available_space_gb" -lt "$required_space_gb" ] || [ "$model_space_gb" -lt "$required_space_gb" ]; then
        echo "Warning: Insufficient space available. Cleaning up..." | tee -a "$LOG_FILE"
        cleanup_temp_files
        
        # Check space again after cleanup
        available_space_gb=$(check_available_space "/dev/shm")
        
        if [ "$available_space_gb" -lt "$required_space_gb" ] || [ "$model_space_gb" -lt "$required_space_gb" ]; then
            echo "Error: Still insufficient space after cleanup." | tee -a "$LOG_FILE"
            echo "Need at least ${required_space_gb}GB in temporary and model directories" | tee -a "$LOG_FILE"
            return 1
        fi
    fi
    
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
        
        echo "Using temporary directory: $temp_dir" | tee -a "$LOG_FILE"
        echo "Using cache directory: /workspace/cache/huggingface" | tee -a "$LOG_FILE"
        
        # Try download with cleanup on failure
        echo "Starting download of Wan2.1-T2V-1.3B..." | tee -a "$LOG_FILE"
        export HF_HUB_ENABLE_HF_TRANSFER=1  # Enable faster downloads
        if ! HUGGINGFACE_HUB_CACHE=/workspace/cache/huggingface \
             poetry run huggingface-cli download --resume-download --local-dir-use-symlinks False \
             Wan-AI/Wan2.1-T2V-1.3B --local-dir "$temp_dir" 2>&1 | tee -a "$LOG_FILE"; then
            echo "Download failed. Cleaning up and retrying..." | tee -a "$LOG_FILE"
            cleanup_temp_files
            if ! HUGGINGFACE_HUB_CACHE=/workspace/cache/huggingface \
                 poetry run huggingface-cli download --resume-download --local-dir-use-symlinks False \
                 Wan-AI/Wan2.1-T2V-1.3B --local-dir "$temp_dir" 2>&1 | tee -a "$LOG_FILE"; then
                echo "Download failed after cleanup. Please check your network connection and space." | tee -a "$LOG_FILE"
                return 1
            fi
        fi
        
        echo "Download completed. Verifying downloaded files..." | tee -a "$LOG_FILE"
        ls -la "$temp_dir" | tee -a "$LOG_FILE"
        
        # Move only missing components
        for component in "${missing_components[@]}"; do
            echo "Processing component: $component" | tee -a "$LOG_FILE"
            if [ -d "$temp_dir/$component" ]; then
                echo "Moving $component to final location..." | tee -a "$LOG_FILE"
                rm -rf "$MODEL_DIR/$component" 2>/dev/null || true
                mv "$temp_dir/$component" "$MODEL_DIR/"
                echo "Verifying moved component..." | tee -a "$LOG_FILE"
                ls -la "$MODEL_DIR/$component" | tee -a "$LOG_FILE"
            else
                echo "Warning: Component $component not found in downloaded files" | tee -a "$LOG_FILE"
                ls -R "$temp_dir" | tee -a "$LOG_FILE"
            fi
        done
        
        # Cleanup
        cleanup_temp_files
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