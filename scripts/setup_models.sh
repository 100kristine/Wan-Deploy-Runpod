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
TEMP_DIR="/dev/shm/wan_model_download"

echo "Step 2: Model Storage Setup" | tee -a "$LOG_FILE"

# Function to print diagnostic information
print_diagnostics() {
    echo "=== DIAGNOSTIC INFORMATION ===" | tee -a "$LOG_FILE"
    echo "Current directory: $(pwd)" | tee -a "$LOG_FILE"
    echo "Python version: $(python3 --version)" | tee -a "$LOG_FILE"
    echo "Poetry version: $(poetry --version)" | tee -a "$LOG_FILE"
    
    echo -e "\nDisk Space:" | tee -a "$LOG_FILE"
    df -h | tee -a "$LOG_FILE"
    
    echo -e "\nModel Directory Structure:" | tee -a "$LOG_FILE"
    ls -la "$MODEL_DIR" 2>/dev/null || echo "Model directory does not exist yet" | tee -a "$LOG_FILE"
    
    echo -e "\nCache Directory:" | tee -a "$LOG_FILE"
    ls -la /workspace/cache/huggingface 2>/dev/null || echo "Cache directory does not exist yet" | tee -a "$LOG_FILE"
    
    echo -e "\nPython Dependencies:" | tee -a "$LOG_FILE"
    poetry show | grep -E "huggingface|torch|transformers|hf-transfer" | tee -a "$LOG_FILE"
    
    echo "===========================" | tee -a "$LOG_FILE"
}

# Function to check dependencies
check_dependencies() {
    echo "Checking dependencies..." | tee -a "$LOG_FILE"
    local missing_deps=0
    
    # Check for hf_transfer
    if ! poetry run pip freeze | grep -q "hf-transfer"; then
        echo "Installing hf_transfer for faster downloads..." | tee -a "$LOG_FILE"
        poetry add hf_transfer
    fi
    
    # Verify huggingface-hub installation
    if ! poetry run pip freeze | grep -q "huggingface-hub"; then
        echo "Installing huggingface-hub..." | tee -a "$LOG_FILE"
        poetry add huggingface-hub
        missing_deps=1
    fi
    
    # Verify transformers installation
    if ! poetry run pip freeze | grep -q "transformers"; then
        echo "Installing transformers..." | tee -a "$LOG_FILE"
        poetry add transformers
        missing_deps=1
    fi
    
    if [ $missing_deps -eq 1 ]; then
        echo "Dependencies were missing and have been installed." | tee -a "$LOG_FILE"
    else
        echo "All required dependencies are installed." | tee -a "$LOG_FILE"
    fi
}

# Function to verify huggingface access
verify_huggingface_access() {
    echo "Verifying Hugging Face model access..." | tee -a "$LOG_FILE"
    if ! poetry run python -c "
from huggingface_hub import model_info
try:
    info = model_info('Wan-AI/Wan2.1-T2V-1.3B')
    print(f'Model size: {info.size_name}')
    print(f'Last modified: {info.last_modified}')
    print('Access verified successfully')
except Exception as e:
    print(f'Error accessing model: {str(e)}')
    exit(1)
" 2>&1 | tee -a "$LOG_FILE"; then
        echo "Error: Cannot access Wan-AI/Wan2.1-T2V-1.3B on Hugging Face" | tee -a "$LOG_FILE"
        return 1
    fi
}

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

# Function to check for required files
check_files() {
    echo "Checking for required files..." | tee -a "$LOG_FILE"
    
    # Just check for key file patterns anywhere in the directory
    local has_t5=$(find "$1" -type f -name "*umt5*.pth" -o -name "*t5*.safetensors" 2>/dev/null)
    local has_vae=$(find "$1" -type f -name "*VAE*.pth" -o -name "*vae*.safetensors" 2>/dev/null)
    local has_tokenizer=$(find "$1" -type f -name "tokenizer*.json" -o -name "spiece.model" 2>/dev/null)
    local has_diffusion=$(find "$1" -type f -name "*diffusion*.safetensors" 2>/dev/null)
    
    if [[ -n "$has_t5" ]] && [[ -n "$has_vae" ]] && [[ -n "$has_tokenizer" ]] && [[ -n "$has_diffusion" ]]; then
        echo "✓ All required files found" | tee -a "$LOG_FILE"
        return 0
    else
        echo "× Missing files:" | tee -a "$LOG_FILE"
        [[ -z "$has_t5" ]] && echo "  - T5 model" | tee -a "$LOG_FILE"
        [[ -z "$has_vae" ]] && echo "  - VAE model" | tee -a "$LOG_FILE"
        [[ -z "$has_tokenizer" ]] && echo "  - Tokenizer" | tee -a "$LOG_FILE"
        [[ -z "$has_diffusion" ]] && echo "  - Diffusion model" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to download model files if needed
download_model() {
    mkdir -p "$TEMP_DIR"
    export HF_HUB_ENABLE_HF_TRANSFER=1
    export HF_TRANSFER_DISABLE_PROGRESS_BARS=0
    
    echo "Downloading model files..." | tee -a "$LOG_FILE"
    if ! HUGGINGFACE_HUB_CACHE=/workspace/cache/huggingface \
         poetry run huggingface-cli download --resume-download \
         --local-dir-use-symlinks False \
         Wan-AI/Wan2.1-T2V-1.3B \
         --local-dir "$TEMP_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        echo "Download failed" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Move everything to final location
    echo "Moving files to final location..." | tee -a "$LOG_FILE"
    mv "$TEMP_DIR"/* "$MODEL_DIR/" 2>/dev/null || true
    
    # Clean up
    rm -rf "$TEMP_DIR"
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

# Main execution
echo "Starting setup with diagnostics..." | tee -a "$LOG_FILE"
print_diagnostics
check_dependencies

if ! verify_huggingface_access; then
    echo "Failed to verify Hugging Face access. Please check your internet connection and try again." | tee -a "$LOG_FILE"
    exit 1
fi

# Main process: verify, download missing, verify again
while true; do
    if verify_models; then
        break
    fi
    
    if [ "$LOCAL_TEST" = "true" ]; then
        create_dummy_files
    else
        download_model
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