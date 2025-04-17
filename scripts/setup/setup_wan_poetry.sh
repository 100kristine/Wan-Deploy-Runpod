#!/bin/bash
set -e

echo "Setting up environment for Wan2.1..."

cd /workspace/Wan2.1

# If virtual environment doesn't exist, create it
if [ ! -d ".venv" ]; then
    echo "Creating new virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

# Upgrade pip and install build tools if needed
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

# Install dependencies only if they're not already installed
if ! python -c "import torch" 2>/dev/null; then
    echo "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
else
    echo "✓ Dependencies already installed"
fi

# Install flash-attn only if not already installed
if ! python -c "import flash_attn" 2>/dev/null; then
    echo "Installing flash-attn..."
    TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6" pip install flash-attn --no-build-isolation
else
    echo "✓ flash-attn already installed"
fi

# Now install Wan2.1 in development mode using setuptools directly
echo "Installing Wan2.1..."
# Create a temporary setup.py if it doesn't exist
if [ ! -f "setup.py" ]; then
    echo "Creating setup.py..."
    cat > setup.py << 'EOL'
from setuptools import setup, find_packages

setup(
    name="wan",
    version="2.1.0",
    packages=find_packages(),
    install_requires=open("requirements.txt").read().splitlines()
)
EOL
fi

python setup.py develop --no-deps  # --no-deps prevents reinstalling dependencies

echo "✓ Wan2.1 environment setup complete!" 