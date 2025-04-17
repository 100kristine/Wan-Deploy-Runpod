# Wan Model Deployment on RunPod

Quick instructions for generating videos using Wan2.1 on RunPod.

## Generating Videos

After setup is complete (see RUNPOD_README.md for setup instructions), you can generate videos:

### Image to Video Generation

```bash
cd /workspace/Wan2.1

# Using 1.3B model (faster, works on consumer GPUs):
poetry run python generate.py --task i2v-1.3B \
  --size 480x832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
  --image_path input.jpg \
  --frame_num 16

# Using 14B model (better quality, needs more VRAM):
poetry run python generate.py --task i2v-14B \
  --size 480x832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-14B \
  --image_path input.jpg \
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
2. Use the public URL of an image: `wget https://your-image-url.jpg`
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