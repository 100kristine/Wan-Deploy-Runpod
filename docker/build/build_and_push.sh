#!/bin/bash

# Exit on any error and print commands
set -ex

# Configuration
IMAGE_NAME="kiihara/wan-deploy"
TAG="cuda12.5"

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Error: docker is not installed or not in PATH"
    exit 1
fi

# Check if user is logged in to Docker Hub
if ! docker info 2>/dev/null | grep "Username:" > /dev/null; then
    echo "❌ Error: Not logged in to Docker Hub. Please run 'docker login' first."
    exit 1
fi

echo "🔨 Building Docker image..."
if ! docker build -t ${IMAGE_NAME}:${TAG} .; then
    echo "❌ Error: Docker build failed"
    exit 1
fi

echo "🏷️ Tagging as latest..."
if ! docker tag ${IMAGE_NAME}:${TAG} ${IMAGE_NAME}:latest; then
    echo "❌ Error: Failed to tag image as latest"
    exit 1
fi

echo "⬆️ Pushing Docker images..."
if ! docker push ${IMAGE_NAME}:${TAG}; then
    echo "❌ Error: Failed to push tagged image"
    exit 1
fi

if ! docker push ${IMAGE_NAME}:latest; then
    echo "❌ Error: Failed to push latest image"
    exit 1
fi

echo "✅ Success! Images pushed to Docker Hub:"
echo "  - ${IMAGE_NAME}:${TAG}"
echo "  - ${IMAGE_NAME}:latest" 