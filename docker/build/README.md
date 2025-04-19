# Docker Build Instructions

## Repository Information
- Docker Hub Repository: `kiihara/wan-deploy-runpod`
- Base Image: `nvidia/cuda:12.1.1-devel-ubuntu22.04`

## Building and Pushing

```bash
# Build the image
docker build -t kiihara/wan-deploy-runpod:latest .

# Push to Docker Hub
docker push kiihara/wan-deploy-runpod:latest
```

## Included Tools
- Python 3.10
- Poetry
- AWS CLI v2
- Git
- Basic development tools (vim, curl, wget, zip/unzip)
- SSH server for RunPod web terminal

## Environment Variables
See `.env.template` in the root directory for required environment variables.

## Notes
- The image is optimized for RunPod deployment
- Uses NVIDIA CUDA 12.1.1 base image
- Configured for x86_64/amd64 architecture only 