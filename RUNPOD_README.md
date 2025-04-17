# RunPod Deployment Guide

## Prerequisites
- RunPod instance with A100/H100 (40GB+ VRAM)
- Network volume mounted at `/workspace/models`
- Base image: `kiihara/wan-deploy:cuda12.5`

## Script Organization

Our scripts are organized into three categories:

### Setup Scripts (`scripts/setup/`)
- Initial environment setup
- Model downloads
- Wan2.1 environment configuration

### Run Scripts (`scripts/run/`)
Convenience scripts for common operations:
```bash
# Quick video generation (small size)
./scripts/run/video_small.sh input.jpg              # Default: 480*832
./scripts/run/video_small.sh -s "720*1280" input.jpg  # Larger size
./scripts/run/video_small.sh -t "t2v-1.3B" input.jpg  # Text to video
```

### Utility Scripts (`scripts/utils/`)
Helper scripts for maintenance and debugging.

## Setup Instructions

### Option 1: Quick Start (Individual Scripts)
```bash
# 1. Clone deployment repository
git clone https://github.com/100kristine/Wan-Deploy-Runpod.git
cd Wan-Deploy-Runpod/scripts

# 2. Run initialization script
chmod +x setup/init_setup.sh setup/setup_wan_poetry.sh
./setup/init_setup.sh

# 3. Run setup scripts
./setup/setup_env.sh
./setup/setup_models.sh

# 4. Clone and setup Wan2.1
cd /workspace
git clone https://github.com/Wan-Video/Wan2.1
./Wan-Deploy-Runpod/scripts/setup/setup_wan_poetry.sh  # Creates and configures virtual environment
```

### Option 2: All-in-One Setup (Beta)
```bash
./scripts/run_all.sh
```

## Running Video Generation

### Quick Start (One-liner to activate environment)
```bash
cd /workspace/Wan2.1 && source .venv/bin/activate
```

### Available Video Sizes
- 480*832 (portrait, recommended)
- 832*480 (landscape)
- 720*1280 (HD portrait)
- 1280*720 (HD landscape)
- 1024*1024 (square)

### Generation Methods

1. Using shortcuts (easiest):
```bash
# First, set up shortcuts (only needed once per pod)
./scripts/utils/setup_shortcuts.sh

# Then use the shortcuts:
wanv input.jpg            # Vertical video (480*832)
wanh input.jpg            # Horizontal video (832*480)
wanhd input.jpg           # HD vertical video (720*1280)
want "a cat dancing"      # Text-to-video

# All shortcuts support additional options:
wanv -f 32 input.jpg     # 32 frames
wanh --frames 24 input.jpg  # 24 frames
```

2. Using convenience script:
```bash
./scripts/run/video_small.sh input.jpg                    # Default (vertical)
./scripts/run/video_small.sh -s vertical input.jpg        # Same as above
./scripts/run/video_small.sh -s hdv input.jpg            # HD vertical
./scripts/run/video_small.sh -s square input.jpg         # Square format
./scripts/run/video_small.sh -t "t2v-1.3B" "cat dancing" # Text to video
./scripts/run/video_small.sh --help                      # Show all options
```

Resolution shortcuts:
- `vertical`, `v`, `portrait`, `p` → 480*832
- `horizontal`, `h`, `landscape`, `l` → 832*480
- `hdv`, `hd-vertical` → 720*1280
- `hdh`, `hd-horizontal` → 1280*720
- `square`, `s` → 1024*1024

3. Manual command (for advanced options):
```bash
# Activate environment if needed
source /workspace/Wan2.1/.venv/bin/activate

# Generate video
python generate.py --task i2v-1.3B --size 480*832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
  --image_path input.jpg \
  --frame_num 16
```

⚠️ **Important Notes**:
1. Always use `*` not `x` in size parameters (e.g., `480*832` not `480x832`)
2. Make sure you're in the virtual environment (should see `(.venv)` in prompt)
3. First run might be slower due to model loading

## Detailed Steps

### 1. Initial Setup
The `init_setup.sh` script handles:
- Installing system dependencies
- Setting up Poetry
- Configuring git
- Making scripts executable

### 2. Environment Setup
The `setup_env.sh` script:
- Sets up Python environment with Poetry
- Installs PyTorch and other dependencies
- Caches the environment for faster reuse

### 3. Model Setup
The `setup_models.sh` script:
- Downloads model files from Hugging Face
- Verifies file integrity
- Sets up proper directory structure

### 4. Wan2.1 Setup
The `setup_wan_poetry.sh` script:
- Creates a dedicated virtual environment for Wan2.1
- Uses setuptools (Wan2.1's native build system)
- Installs all required dependencies
- Keeps deployment and model environments separate

Note: Wan2.1 uses its own virtual environment with setuptools, separate from the deployment environment which uses Poetry. This separation ensures compatibility and prevents dependency conflicts.

## Troubleshooting

### Authentication Issues
- For git: Check configuration with `git config --list`

### Environment Setup Issues
- If environment setup fails, delete `.venv` and retry
- Check if cached environment exists at `/workspace/models/env_cache`
- Verify CUDA is available: `poetry run python -c "import torch; print(torch.cuda.is_available())"`

### Model Setup Issues
- Verify network volume is mounted: `df -h | grep /workspace/models`
- Check model files exist and have correct permissions
- Look for detailed errors in `/workspace/models/model_setup.log`
- If model files are missing, rerun the model setup script

### Generation Issues
- Start with smaller resolution (480p) for initial tests
- Use `offload_model=True` if running into memory issues
- Check GPU memory: `nvidia-smi`

### Poetry/Dependencies Issues
If you get dependency errors in the Wan2.1 environment:
1. Make sure you've activated the correct environment: `source /workspace/Wan2.1/.venv/bin/activate`
2. Try reinstalling dependencies: `pip install -r requirements.txt`
3. If issues persist with flash-attn, try: `pip install flash-attn --no-build-isolation`

### Model Loading Issues
- Verify model files exist in `/workspace/models/Wan2.1-T2V-1.3B/`
- Check file permissions
- Try using `--offload_model True` for memory issues

### File Transfer Issues
If having trouble transferring files to RunPod:
1. Use RunPod's web terminal file upload
2. Use wget for files with public URLs
3. Use base64 encoding for small files:
   ```bash
   # Local machine:
   base64 file.jpg > file.b64
   # Copy content, then on RunPod:
   echo 'paste_content' | base64 -d > file.jpg
   ```

## Logs Location
- Environment setup: `/workspace/models/env_cache/setup.log`
- Model setup: `/workspace/models/model_setup.log`

## Recovery Steps
If a step fails:
1. Check the respective log file
2. Fix the reported issue
3. Re-run only the failed step (each step is independent)
4. If environment is corrupted, restore from cache: `cp -r /workspace/models/env_cache/cached_venv .venv` 