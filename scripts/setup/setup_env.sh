#!/bin/bash
set -e  # Exit on any error

# Check if we're in local testing mode
if [ "$LOCAL_TEST" = "true" ]; then
    NETWORK_VOLUME="./local_test_models"
    echo "Running in local test mode - some GPU features will be skipped"
else
    NETWORK_VOLUME="/workspace/models"
fi

CACHE_DIR="$NETWORK_VOLUME/env_cache"
ENV_CACHE="$CACHE_DIR/cached_venv"
LOG_FILE="$CACHE_DIR/setup.log"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

echo "Step 1: Python Environment Setup" | tee -a "$LOG_FILE"

# Function to test Python environment
test_environment() {
    echo "Testing Python environment..." | tee -a "$LOG_FILE"
    if [ "$LOCAL_TEST" = "true" ]; then
        if poetry run python -c "import torch; print('PyTorch:', torch.__version__)" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        if poetry run python -c "import torch; print('PyTorch:', torch.__version__); import flash_attn; print('Flash-attention installed')" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to restore cached environment
restore_cached_env() {
    if [ -d "$ENV_CACHE" ]; then
        echo "Restoring cached virtual environment..." | tee -a "$LOG_FILE"
        cp -r "$ENV_CACHE" .venv
        if test_environment; then
            echo "✓ Successfully restored cached environment" | tee -a "$LOG_FILE"
            return 0
        else
            echo "× Cached environment is corrupted, will create new one" | tee -a "$LOG_FILE"
            rm -rf .venv
            return 1
        fi
    fi
    return 1
}

# Try to restore from cache first
if ! restore_cached_env; then
    echo "Setting up new Python environment..." | tee -a "$LOG_FILE"
    
    # Install Poetry if not present
    if ! command -v poetry &> /dev/null; then
        echo "Installing Poetry..." | tee -a "$LOG_FILE"
        curl -sSL https://install.python-poetry.org | python3 -
    fi

    # Install dependencies
    echo "Installing project dependencies..." | tee -a "$LOG_FILE"
    poetry install

    # Install flash-attention only if not in local test mode
    if [ "$LOCAL_TEST" != "true" ]; then
        echo "Installing flash-attention..." | tee -a "$LOG_FILE"
        poetry run pip install --upgrade pip setuptools wheel
        poetry run pip install flash-attn --no-build-isolation
    else
        echo "Skipping flash-attention installation in local test mode" | tee -a "$LOG_FILE"
    fi

    # Test the environment
    if test_environment; then
        echo "✓ Environment setup successful" | tee -a "$LOG_FILE"
        
        # Cache the working environment
        echo "Caching successful environment..." | tee -a "$LOG_FILE"
        rm -rf "$ENV_CACHE"
        cp -r .venv "$ENV_CACHE"
    else
        echo "× Environment setup failed" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

echo "Environment setup complete! 🎉" | tee -a "$LOG_FILE" 