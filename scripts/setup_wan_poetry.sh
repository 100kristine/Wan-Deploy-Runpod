#!/bin/bash
set -e

echo "Setting up environment for Wan2.1..."

cd /workspace/Wan2.1

# Create a new virtual environment specifically for Wan2.1
python3 -m venv .venv
source .venv/bin/activate

# Upgrade pip and install build tools
pip install --upgrade pip setuptools wheel

# Set up CUDA environment variables
export CUDA_HOME=/usr/local/cuda-12.1
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# Verify CUDA setup
echo "Verifying CUDA installation..."
if ! command -v nvcc &> /dev/null; then
    echo "Error: CUDA compiler (nvcc) not found. Installing CUDA toolkit..."
    apt-get update && apt-get install -y cuda-toolkit-12-1
fi

# Install dependencies except flash-attn first
pip install torch>=2.4.0 \
    torchvision>=0.19.0 \
    opencv-python>=4.9.0.80 \
    diffusers>=0.31.0 \
    transformers>=4.49.0 \
    tokenizers>=0.20.3 \
    accelerate>=1.1.1 \
    tqdm \
    imageio \
    easydict \
    ftfy \
    dashscope \
    imageio-ffmpeg \
    gradio>=5.0.0 \
    numpy>=1.23.5

# Install flash-attn with specific configuration
echo "Installing flash-attn..."
TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6" pip install flash-attn --no-build-isolation

# Now install Wan2.1 in development mode
pip install -e .

echo "✓ Wan2.1 environment setup complete!" 