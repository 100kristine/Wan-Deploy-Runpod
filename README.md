# Wan2.1 RunPod Deployment

This repository contains two main components:
1. Video Generation Pipeline (`runpod_video_pipeline/`)
2. Docker Container Build (`docker/build/`)

## Quick Links
- [Video Pipeline Documentation](runpod_video_pipeline/README.md)
- [Docker Build Instructions](docker/build/README.md)
- [RunPod Setup Guide](RUNPOD_README.md)

## Quick Start: Generate Videos

### Direct Command (Most Flexible)
```bash
# Basic vertical video (480*832)
python generate.py \
    --task t2v-1.3B \
    --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
    --size 480*832 \
    --frame_num 50 \
    --image input.jpg \
    --prompt "moving..."

# Horizontal video (832*480)
python generate.py \
    --task t2v-1.3B \
    --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
    --size 832*480 \
    --frame_num 50 \
    --image input.jpg \
    --prompt "moving..."
```

Required parameters:
- `--image`: Path to your input image
- `--task`: Always use `t2v-1.3B` for the 1.3B model
- `--ckpt_dir`: Path to model directory
- `--size`: Video dimensions (use `*` not `x`)
- `--frame_num`: Number of frames to generate
- `--prompt`: Text prompt to guide the video generation

### Using Convenience Script
```bash
# Basic usage
./runpod_video_pipeline/scripts/run/video_small.sh --image input.jpg

# With custom settings
./runpod_video_pipeline/scripts/run/video_small.sh \
    --image input.jpg \
    --prompt "zooming into the sunset" \
    --frames 80 \
    --size 832*480
```

## Supported Formats (1.3B Model)
- Vertical: 480*832 (default)
- Horizontal: 832*480

## Important Notes
- Always use `*` not `x` in size parameters (e.g., `480*832`)
- The image parameter is required
- Default prompt is "moving..." if not specified
- Default frame count is 50 if not specified
- First run might be slower due to model loading

## Generating Videos

After setup is complete (see RUNPOD_README.md for setup instructions), you can generate videos.
First, change to the Wan2.1 directory:
```bash
cd /workspace/Wan2.1
```

### Image to Video Generation
```bash
# Using 1.3B model (pre-installed):
poetry run python generate.py --task i2v-1.3B \
  --size 480*832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
  --image input.jpg \
  --frame_num 16

# Using 14B model (requires separate download):
# NOTE: This command won't work until you download the 14B model
poetry run python generate.py --task i2v-14B \
  --size 480*832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-14B \
  --image input.jpg \
  --frame_num 16 \
  --offload_model True
```

### Common Resolution Options
- 480p: `--size 480x832`
- 720p: `--size 1280x720` (may need `--offload_model True` for memory)
- Square: `--size 624x624`

### Getting Images to RunPod

Options for uploading images:
1. Use RunPod's built-in file upload in the web terminal
2. Use image URLs directly in commands: `wanv https://your-image-url.jpg`
3. Base64 encode your image and decode on RunPod:
   ```bash
   # On your local machine:
   base64 your_image.jpg > image.b64
   # Copy the content of image.b64
   
   # On RunPod:
   echo 'paste_base64_content_here' | base64 -d > input.jpg
   ```

### Tips
- Start with 480p resolution for faster testing
- Use `--frame_num 16` for ~5 second videos
- Add `--seed 42` for reproducible results
- Generated videos will be in the `outputs` directory

## 🔔 Notifications
The scripts now include sound notifications:
- 1 bell: Video generation complete
- 2 bells: S3 upload complete

## 📤 S3 Upload
You can automatically upload generated videos to S3. First, set up your AWS credentials:

1. Copy and edit the .env file:
```bash
cp .env.template .env
# Edit .env with your AWS credentials and settings
```

2. Use one of these methods to upload:
```bash
# Auto-upload after generation:
wanv -u input.jpg              # Generate and upload vertical video
wanh -u input.jpg              # Generate and upload horizontal video
want -u "walking in rain"      # Generate and upload text-to-video

# Manual upload later:
wans3 outputs/i2v              # Upload all i2v outputs
wans3 outputs/t2v              # Upload all t2v outputs
wans3 -p custom/path/ file.mp4 # Upload with custom S3 prefix
```

## Docker Build
Docker-related files are in the `docker/build` directory. See `docker/build/README.md` for build instructions.

## Quick Reference: Video Generation Commands

### Generate Video from Image (1.3B Model)
```bash
# Vertical video (512x768) - 80 frames
python generate.py --image_path "your_image.jpg" --task i2v --model_path /workspace/models/Wan2.1-T2V-1.3B --num_frames 80 --size 512x768

# Horizontal video (768x512) - 80 frames
python generate.py --image_path "your_image.jpg" --task i2v --model_path /workspace/models/Wan2.1-T2V-1.3B --num_frames 80 --size 768x512
```

Common parameters:
- `--image_path`: Path to your input image
- `--task`: Use `i2v` for image-to-video generation
- `--model_path`: Path to the 1.3B model
- `--num_frames`: Number of frames to generate (80 is good for marketing clips)
- `--size`: Video dimensions (512x768 for vertical, 768x512 for horizontal)