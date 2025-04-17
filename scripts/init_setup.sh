#!/bin/bash
set -e  # Exit on any error

echo "Starting initial RunPod setup..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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
huggingface-hub = "^0.30.2"
torch = "^2.0.0"
transformers = "^4.30.0"

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

# Check for Hugging Face token
if [ -z "$HUGGING_FACE_TOKEN" ]; then
    echo "Hugging Face token not found."
    echo "Please set your token: export HUGGING_FACE_TOKEN='your_token'"
    exit 1
fi

# Login to Hugging Face using the token
echo "Logging into Hugging Face..."
poetry run huggingface-cli login --token "$HUGGING_FACE_TOKEN"

# Make all scripts executable
chmod +x *.sh

echo "Initial setup complete! 🎉"
echo "You can now proceed with running setup_env.sh and setup_models.sh" 