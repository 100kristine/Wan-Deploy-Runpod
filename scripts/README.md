# Setup Scripts

These scripts automate the setup process for Wan2.1 on RunPod instances, with built-in testing and caching.

## Quick Start
```bash
# Make scripts executable
chmod +x *.sh

# Step 1: Setup Python environment
./setup_env.sh

# Step 2: Setup model storage
./setup_models.sh
```

## Script Details

### setup_env.sh
Sets up the Python environment with caching:
- Attempts to restore cached environment first
- Installs Poetry and dependencies if needed
- Tests environment with PyTorch and flash-attention
- Caches successful environment to network volume

**Recovery**: If script fails, delete `.venv` and retry. Cached environment will be used if available.

### setup_models.sh
Verifies model storage and tests loading:
- Checks network volume mounting
- Verifies all required model files
- Tests basic model loading
- Logs all operations

**Recovery**: If script fails, check model files and network volume mounting.

## Logs
- Environment setup: `/workspace/models/env_cache/setup.log`
- Model setup: `/workspace/models/model_setup.log`

## Testing
Each script includes built-in tests:
```bash
# Test environment setup
./setup_env.sh
poetry run python -c "import torch; print(torch.__version__)"

# Test model setup
./setup_models.sh
ls /workspace/models/Wan2.1-T2V-14B/*checkpoint*
``` 