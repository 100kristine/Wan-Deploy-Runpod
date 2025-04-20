#!/bin/bash

# Initialize poetry environment if not already done
cd /workspace
if [ ! -d ".venv" ]; then
    echo "Initializing Poetry environment..."
    poetry install --no-root
fi

# Ensure Jupyter is installed in the Poetry environment
echo "Ensuring Jupyter is installed..."
poetry run pip install jupyter notebook --quiet

# Start Jupyter notebook in the background
echo "Starting Jupyter notebook server..."
poetry run jupyter notebook \
    --ip 0.0.0.0 \
    --port 8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --notebook-dir=/workspace >> /workspace/jupyter.log 2>&1 &

# Wait a few seconds to check if Jupyter started successfully
sleep 5
if pgrep -f "jupyter-notebook" > /dev/null; then
    echo "✓ Jupyter notebook is running on port 8888"
    echo "  Check /workspace/jupyter.log for details"
else
    echo "⚠️  Failed to start Jupyter notebook"
    echo "  Check /workspace/jupyter.log for errors"
fi

# Keep the container running
tail -f /dev/null 