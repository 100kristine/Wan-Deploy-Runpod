# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# 🚫 DO NOT REMOVE OR MODIFY THESE ARCHITECTURE SETTINGS 🚫
# These warnings and checks are critical for RunPod GPU support
# Removing them will cause "Exec format error" on RunPod!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# If building on Mac/ARM, you MUST use these exact commands:
# docker buildx create --use
# docker buildx build --platform linux/amd64 -t kiihara/wan-deploy-runpod:latest . --push
#
# If you see these warnings, they are GOOD and expected:
# - "FromPlatformFlagConstDisallowed"
# - "Requested platform linux/arm64 does not match linux/amd64"
#
# These warnings mean the image will work on RunPod's NVIDIA GPUs!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Standard minimalist warning
# ⚠️ IMPORTANT: KEEP THIS DOCKERFILE MINIMAL! ⚠️
# This Dockerfile should contain only the absolute bare minimum requirements.
# DO NOT add additional dependencies here - they should be installed via Poetry
# during runtime setup instead. Adding dependencies here will significantly
# increase build times, especially on Mac/non-Linux systems.
#
# If you need additional packages, add them to:
# 1. scripts/init_setup.sh for system packages
# 2. scripts/setup_wan_poetry.sh for Python packages
#
# This separation ensures fast builds while maintaining flexibility.

FROM --platform=linux/amd64 nvidia/cuda:12.1.1-devel-ubuntu22.04

# Triple-check architecture - DO NOT REMOVE THESE CHECKS!
# These prevent silent failures on RunPod
RUN set -ex; \
    if [ "$(uname -m)" != "x86_64" ]; then \
        echo "❌ FATAL: This container MUST run on x86_64/amd64 for NVIDIA GPU support"; \
        echo "❌ Current architecture: $(uname -m)"; \
        echo "❌ Did you build with: --platform linux/amd64 ?"; \
        exit 1; \
    fi; \
    echo "✅ Architecture check passed: $(uname -m)"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    POETRY_VERSION=1.7.1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VENV="/opt/poetry-venv" \
    POETRY_NO_INTERACTION=1 \
    PROJECT_NAME="Wan-Deploy-Runpod"

# Install Python, git, and essential development tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    openssh-server \
    tmux \
    vim \
    curl \
    wget \
    zip \
    unzip \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Setup SSH for web terminal
RUN mkdir /var/run/sshd && \
    echo 'root:runpod' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Install Poetry
RUN python3 -m pip install --no-cache-dir poetry==${POETRY_VERSION}

# Configure Poetry
RUN poetry config virtualenvs.in-project true

# Create and set workspace
WORKDIR /workspace

# Create pyproject.toml with correct naming (matching GitHub repo)
RUN echo '[tool.poetry]\n\
name = "Wan-Deploy-Runpod"\n\
version = "0.1.0"\n\
description = "RunPod deployment template"\n\
authors = ["RunPod User <user@runpod.io>"]\n\
\n\
[tool.poetry.dependencies]\n\
python = "^3.10"\n\
torch = "*"\n\
transformers = "*"\n\
\n\
[build-system]\n\
requires = ["poetry-core"]\n\
build-backend = "poetry.core.masonry.api"' > pyproject.toml

# Set default git config
RUN git config --global user.name "RunPod User" && \
    git config --global user.email "user@runpod.io"

# Create startup script
RUN echo '#!/bin/bash\n\
cd /workspace\n\
# Install dependencies without installing the project itself\n\
poetry install --no-root\n\
service ssh start\n\
echo "🚀 Container is ready!"\n\
# Keep container running\n\
tail -f /dev/null' > /startup.sh && \
    chmod +x /startup.sh

# Add a healthcheck that verifies both NVIDIA runtime and architecture
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD nvidia-smi && [ "$(uname -m)" = "x86_64" ] || exit 1

# Expose SSH port
EXPOSE 22

# Set the entry point
ENTRYPOINT ["/startup.sh"] 