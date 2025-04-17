FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

# Ensure we're running on the correct architecture
RUN [ "$(uname -m)" = "x86_64" ] || (echo "❌ This container must run on x86_64/amd64" && false)

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    POETRY_VERSION=1.7.1 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VENV="/opt/poetry-venv"

# Install Python and git (minimal dependencies)
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN python3 -m pip install --no-cache-dir poetry==${POETRY_VERSION}

# Configure Poetry
RUN poetry config virtualenvs.in-project true

# Create and set workspace
WORKDIR /workspace

# Add a healthcheck that verifies both NVIDIA runtime and architecture
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD nvidia-smi && [ "$(uname -m)" = "x86_64" ] || exit 1 