#!/bin/bash

echo "Starting startup script..."
cd /workspace
echo "Current directory: $(pwd)"

# Verify Jupyter installation
echo "Verifying Jupyter installation..."
if poetry run which jupyter > /dev/null; then
    echo "✓ Jupyter is installed"
else
    echo "⚠️  Jupyter not found in Poetry environment!"
    exit 1
fi

# Start Jupyter notebook in the background
echo "Starting Jupyter notebook server..."
poetry run jupyter notebook \
    --ip 0.0.0.0 \
    --port 8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --notebook-dir=/workspace 2>&1 | tee /workspace/jupyter.log &

# Wait a few seconds to check if Jupyter started successfully
echo "Waiting for Jupyter to start..."
sleep 5
if pgrep -f "jupyter-notebook" > /dev/null; then
    echo "✓ Jupyter notebook is running on port 8888"
    echo "  Log file: /workspace/jupyter.log"
    cat /workspace/jupyter.log
else
    echo "⚠️  Failed to start Jupyter notebook"
    echo "Error log:"
    cat /workspace/jupyter.log
    exit 1
fi

# Start SSH service (if needed)
service ssh start

echo "🚀 Container is ready!"

# Keep container running
echo "Keeping container alive..."
tail -f /dev/null 