#!/bin/bash
set -e  # Exit on any error

# Define network volume location
NETWORK_VOLUME="/workspace/models"
CACHE_DIR="$NETWORK_VOLUME/env_cache"
INIT_CACHE="$CACHE_DIR/init_setup_complete"

echo "Starting initial RunPod setup..."

# Check if already initialized from cache
if [ -f "$INIT_CACHE" ]; then
    echo "Found cached initialization, restoring settings..."
    # Restore git config
    if [ -f "$CACHE_DIR/git_config" ]; then
        while IFS='=' read -r key value; do
            git config --global "$key" "$value"
        done < "$CACHE_DIR/git_config"
    fi
    
    # Restore Poetry config
    if [ -f "$CACHE_DIR/poetry_config" ]; then
        mkdir -p ~/.config/pypoetry
        cp "$CACHE_DIR/poetry_config" ~/.config/pypoetry/config.toml
    fi
    
    echo "Cached initialization restored! 🎉"
    exit 0
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Create cache directory
mkdir -p "$CACHE_DIR"

# Install system dependencies
echo "Installing system dependencies..."
apt-get update && apt-get install -y git curl

# Install Poetry if not present
if ! command_exists poetry; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    export PATH="/root/.local/bin:$PATH"  # Add Poetry to PATH
fi

# Configure Poetry to create virtual environments in the project directory
poetry config virtualenvs.in-project true

# Cache Poetry configuration
mkdir -p ~/.config/pypoetry
cp ~/.config/pypoetry/config.toml "$CACHE_DIR/poetry_config" 2>/dev/null || true

# Install huggingface-hub through Poetry
echo "Setting up Python dependencies..."
if [ ! -f "pyproject.toml" ]; then
    echo "Creating pyproject.toml..."
    cat > pyproject.toml << EOL
[tool.poetry]
name = "wan-deploy-runpod"
version = "0.1.0"
description = "Deployment scripts for Wan2.1 on RunPod"
authors = ["Your Name <your.email@example.com>"]

[tool.poetry.dependencies]
python = "^3.10"
huggingface-hub = "^0.21.1"
torch = "^2.2.0"
transformers = "^4.37.2"
accelerate = "^0.27.0"
safetensors = "^0.4.2"
bitsandbytes = "^0.42.0"

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"
EOL
fi

# Install dependencies
poetry install

# Configure git if not already configured
if [ -z "$(git config --global user.name)" ]; then
    echo "Git user name not configured."
    echo "Please run: git config --global user.name 'Your Name'"
    echo "      and: git config --global user.email 'your.email@example.com'"
    exit 1
fi

# Cache git configuration
git config --global --list > "$CACHE_DIR/git_config"

# Make all scripts executable
chmod +x *.sh

# Mark initialization as complete
touch "$INIT_CACHE"

echo "Initial setup complete and cached! 🎉"
echo "You can now proceed with running setup_env.sh and setup_models.sh" 