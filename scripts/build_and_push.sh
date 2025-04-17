#!/bin/bash

# Exit on error
set -e

# Configuration
DOCKER_USERNAME="kiihara"
IMAGE_NAME="wan-deploy-runpod"
TAG="latest"

# Full image name
FULL_IMAGE_NAME="$DOCKER_USERNAME/$IMAGE_NAME:$TAG"

# Build the Docker image
echo "Building Docker image: $FULL_IMAGE_NAME"
docker build -t $FULL_IMAGE_NAME -f docker/Dockerfile .

# Push the image to Docker Hub
echo "Pushing image to Docker Hub..."
docker push $FULL_IMAGE_NAME

echo "Successfully built and pushed $FULL_IMAGE_NAME" 