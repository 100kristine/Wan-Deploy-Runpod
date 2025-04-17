# RunPod Deployment Guide

## Prerequisites
- RunPod instance with A100/H100 (40GB+ VRAM)
- Network volume mounted at `/workspace/models`
- Base image: `kiihara/wan-deploy:cuda12.5`

## Setup Options

### Option 1: Quick Start (Individual Scripts)
```bash
# 1. Clone deployment repository
git clone https://github.com/100kristine/Wan-Deploy-Runpod.git
cd Wan-Deploy-Runpod/scripts

# 2. Run initialization script
chmod +x init_setup.sh setup_wan_poetry.sh
./init_setup.sh

# 3. Run setup scripts
./setup_env.sh
./setup_models.sh

# 4. Clone and setup Wan2.1
cd /workspace
git clone https://github.com/Wan-Video/Wan2.1
./Wan-Deploy-Runpod/scripts/setup_wan_poetry.sh  # This creates and sets up the virtual environment
```

### Option 2: All-in-One Setup (Beta)
⚠️ Note: This option is still being tested and may not work in all environments.
```bash
git clone https://github.com/100kristine/Wan-Deploy-Runpod.git
cd Wan-Deploy-Runpod/scripts
chmod +x run_all.sh
./run_all.sh
```

## Running Image-to-Video Generation

### Quick Start Command
Use this one-liner to activate the environment and cd to the right directory:
```bash
cd /workspace/Wan2.1 && source .venv/bin/activate
```

### Generate Videos
After activating the environment:

```bash
# For 1.3B model (faster, works on consumer GPUs):
python generate.py --task i2v-1.3B --size 480x832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-1.3B \
  --image_path path/to/your/image.jpg

# For 14B model (better quality, requires more VRAM):
python generate.py --task i2v-14B --size 480x832 \
  --ckpt_dir /workspace/models/Wan2.1-T2V-14B \
  --image_path path/to/your/image.jpg \
  --offload_model True  # Use this if running out of VRAM
```

⚠️ **Important**: Always make sure you're in the virtual environment before running commands. You should see `(.venv)` at the start of your prompt. If not, run:
```bash
source /workspace/Wan2.1/.venv/activate
```

If you get a "No module named 'torch'" error:
1. Make sure you're in the virtual environment (you should see `(.venv)` in your prompt)
2. If you just created the virtual environment, run the setup script:
```bash
/workspace/Wan-Deploy-Runpod/scripts/setup_wan_poetry.sh
```

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