#!/bin/bash

# Exit on error
set -e

# Configuration
DOCKER_USERNAME="kiihara"
IMAGE_NAME="wan-deploy-runpod"
TAG="latest"
REQUIRED_PLATFORM="linux/amd64"  # Required platform for NVIDIA compatibility

# Check current architecture
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" = "arm64" ] || [ "$CURRENT_ARCH" = "aarch64" ]; then
    echo "⚠️  Detected ARM architecture ($CURRENT_ARCH)"
    echo "🔍 Building for amd64 using cross-compilation..."
    
    # Verify docker buildx is available
    if ! docker buildx version > /dev/null 2>&1; then
        echo "❌ Error: docker buildx is required for cross-platform builds"
        exit 1
    fi
fi

# Full image name
FULL_IMAGE_NAME="$DOCKER_USERNAME/$IMAGE_NAME:$TAG"

# Remove existing builder if it exists
docker buildx rm amd64_builder 2>/dev/null || true

# Create a new builder instance
echo "🔧 Creating fresh builder instance..."
docker buildx create --name amd64_builder --platform=${REQUIRED_PLATFORM} --use

# Build and push using buildx with caching
echo "🚀 Building Docker image for ${REQUIRED_PLATFORM}: $FULL_IMAGE_NAME"
docker buildx build \
  --builder amd64_builder \
  --platform=${REQUIRED_PLATFORM} \
  --cache-from=type=registry,ref=$FULL_IMAGE_NAME \
  --cache-to=type=inline \
  --push \
  -t $FULL_IMAGE_NAME \
  -f docker/Dockerfile .

# Clean up the builder
echo "🧹 Cleaning up builder..."
docker buildx rm amd64_builder 