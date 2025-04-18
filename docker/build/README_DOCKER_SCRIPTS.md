# Docker Build Instructions

This directory contains all Docker-related files for building and pushing the Wan2.1 RunPod container.

## Files
- `Dockerfile` - Main Dockerfile for the RunPod container
- `docker-compose.yml` - For local testing
- `build_and_push.sh` - Script to build and push to Docker Hub

## Building the Container

1. Using the build script:
```bash
./build_and_push.sh
```

2. Manual build:
```bash
docker build -t your-repo/wan-runpod:latest .
docker push your-repo/wan-runpod:latest
```

## Local Testing
```bash
docker-compose up
```

## Environment Variables
The container expects these environment variables:
- `AWS_ACCESS_KEY_ID` - For S3 uploads
- `AWS_SECRET_ACCESS_KEY` - For S3 uploads
- `AWS_DEFAULT_REGION` - AWS region (e.g., us-east-1)
- `S3_BUCKET_NAME` - Target S3 bucket
- `S3_DEFAULT_PREFIX` - (Optional) Default prefix for uploads
- `S3_ACL` - (Optional) S3 ACL setting (private/public-read) 