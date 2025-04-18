# Wan2.1 RunPod Deployment

This repository contains two main components:
1. Video Generation Pipeline (`runpod_video_pipeline/`)
2. Docker Container Build (`docker/build/`)

## Quick Links
- [Video Pipeline Documentation](runpod_video_pipeline/README.md)
- [Docker Build Instructions](docker/build/README.md)
- [RunPod Setup Guide](RUNPOD_README.md)

## Quick Start: Generate Videos

1. Set up environment (do this once):
```bash
# Set up S3 configuration (optional)
cp .env.template .env
# Edit .env with your AWS credentials

# Set up shortcuts
./runpod_video_pipeline/scripts/utils/setup_shortcuts.sh
```

2. Generate videos using shortcuts:
```bash
# From local files:
wanv input.jpg                    # Vertical video (480*832)
wanh input.jpg                    # Horizontal video (832*480)

# From URLs:
wanv https://example.com/img.jpg  # Download and generate from URL
wanh https://example.com/img.jpg  # Same for horizontal

# Text to video:
want "a sunset beach"             # Text-to-video with prompt

# Add more frames:
wanv -f 32 input.jpg             # 32 frames instead of default 16
```

Available shortcuts:
- `wanv` - Vertical video (480*832)
- `wanh` - Horizontal video (832*480)
- `wanhd` - HD vertical (720*1280, only for 14B model)
- `want` - Text-to-video (requires text prompt)

See RUNPOD_README.md for detailed setup and advanced options.

## Supported Formats

### 1.3B Model (Default, Pre-installed)
- 480*832 (vertical)
- 832*480 (horizontal)

### 14B Model (Not Included)
**NOTE: The 14B model is not included by default. You need to download it separately to use these features:**
- 480*832, 832*480
- 720*1280, 1280*720 (HD)
- 1024*1024 (square)

To use the 14B model, you'll need to:
1. Download the model files
2. Update the checkpoint path in the scripts
3. Have sufficient VRAM (recommended: 24GB+)

## Important Notes
- Use `*` not `x` in size parameters (e.g., `480*832`)
- HD sizes (720*1280) require the 14B model (not included)
- First run might be slower due to model loading
- You can use image URLs directly in commands

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