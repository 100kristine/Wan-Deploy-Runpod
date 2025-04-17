# RunPod Deployment Guide

## Prerequisites
- RunPod instance with A100/H100 (40GB+ VRAM)
- Network volume mounted at `/workspace/models`
- Base image: PyTorch 2.0+
- Hugging Face token

## Quick Start
```bash
# 1. Clone deployment repository
git clone https://github.com/100kristine/Wan-Deploy-Runpod.git
cd Wan-Deploy-Runpod/scripts

# 2. Set your Hugging Face token
export HUGGING_FACE_TOKEN='your_token_here'

# 3. Run initialization script
chmod +x init_setup.sh
./init_setup.sh

# 4. Run setup scripts
./setup_env.sh
./setup_models.sh
```

## Detailed Steps

### 1. Initial Setup
The `init_setup.sh` script handles:
- Installing system dependencies
- Setting up Poetry
- Configuring git
- Logging into Hugging Face
- Making scripts executable

If you need to run these steps manually:
```bash
# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Configure git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Login to Hugging Face
export HUGGING_FACE_TOKEN='your_token_here'
poetry run huggingface-cli login --token "$HUGGING_FACE_TOKEN"
```

### 2. Environment Setup
```bash
# Run environment setup script
./setup_env.sh

# Verify success
poetry run python -c "import torch; print('PyTorch:', torch.__version__)"
poetry run python -c "import flash_attn; print('Flash-attention installed')"
```

Expected output:
- PyTorch version should be 2.0.0 or higher
- Flash-attention should be installed
- A cached environment should be created at `/workspace/models/env_cache`

### 3. Model Storage Setup
```bash
# Run model setup script
./setup_models.sh
```

Expected output:
- Should verify all model files are present
- Should successfully load T5 and VAE models
- Directory structure at `/workspace/models/Wan2.1-T2V-14B/` should contain:
  ```
  ├── t5_tokenizer/
  ├── t5_checkpoint/
  ├── vae_checkpoint/
  └── clip_checkpoint/
  ```

### 4. Basic Generation Test
```bash
# Generate a test video
cd ..  # Return to Wan-Deploy-Runpod root directory
poetry run python generate.py --task t2v-14B --frame_num 16 --size '480x832'
```

Expected output:
- Should generate a short test video
- Monitor GPU memory usage (should be ~35GB for 720p)

## Troubleshooting

### Authentication Issues
- For git: Check configuration with `git config --list`
- For Hugging Face: Verify login with `poetry run huggingface-cli whoami`
- If model download fails: Check your Hugging Face token permissions

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

## Logs Location
- Environment setup: `/workspace/models/env_cache/setup.log`
- Model setup: `/workspace/models/model_setup.log`

## Recovery Steps
If a step fails:
1. Check the respective log file
2. Fix the reported issue
3. Re-run only the failed step (each step is independent)
4. If environment is corrupted, restore from cache: `cp -r /workspace/models/env_cache/cached_venv .venv` 