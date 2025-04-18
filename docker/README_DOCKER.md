# Docker Base Image for Wan Deployment

This directory contains the Dockerfile and build scripts for creating a base image with CUDA and Python dependencies pre-installed.

## Base Image Contents

- CUDA 12.5.1 with development tools
- Python 3.10
- Poetry 1.7.1 (pre-installed in a dedicated venv)
- PyTorch 2.1.2 with CUDA support
- Common development tools (git, curl, vim, etc.)
- Ninja build system (for compiling flash-attention)

## Building and Pushing

```bash
# Make the build script executable
chmod +x build_and_push.sh

# Login to Docker Hub (if not already logged in)
docker login

# Build and push to Docker Hub
./build_and_push.sh
```

## Using the Image

The image is available on Docker Hub:
```bash
docker pull kiihara/wan-deploy:cuda12.5
```

### On RunPod
When creating a new pod, use this as your base image:
```
kiihara/wan-deploy:cuda12.5
```

## Why This Base Image?

1. **Pre-installed Dependencies**: Saves time by having CUDA, Python, Poetry, and PyTorch pre-installed
2. **Consistent Environment**: Ensures all deployments use the same versions
3. **Optimized for Wan**: Includes tools needed for flash-attention compilation
4. **Faster Pod Startup**: Reduces the time needed to set up a new RunPod instance

## Updating the Image

To update the image:
1. Modify the Dockerfile if needed
2. Run build_and_push.sh
3. Update your RunPod templates to use the new version 