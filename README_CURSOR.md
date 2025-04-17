# Wan2.1 RunPod Setup Requirements

## ⚠️ VERY IMPORTANT
- Each step should be testable independently
- Cache completed steps on network volume where possible
- If a step fails, previous steps should not need to be repeated
- Test complex integrations locally before RunPod deployment

## Goals Checklist
- [ ] Setup and install on RunPod instance
- [ ] Configure network volume storage for efficient model loading
- [ ] Generate sample video output
- [ ] Integrate with existing S3 pipeline

## Modular Installation Steps

### Step 1: Python Environment Setup (Cacheable ✓)
- [ ] Install Poetry
- [ ] Basic dependencies installation
- [ ] Flash-attention setup
**Test**: `poetry run python -c "import torch; print(torch.__version__)"` 
**Cache**: Save virtual environment to network volume
```bash
# After successful setup:
cp -r .venv /workspace/models/cached_venv
```

### Step 2: Model Storage (Cacheable ✓)
- [ ] Network volume mount
- [ ] Model checkpoint structure verification
**Test**: `ls /workspace/models/Wan2.1-T2V-14B/*checkpoint*`
**Cache**: Models stay on network volume

### Step 3: Basic Generation Test (Independent ✓)
- [ ] Test with minimal example
- [ ] Verify GPU memory usage
**Test**: Generate 1-second test video
```bash
poetry run python generate.py --task t2v-14B --frame_num 16 --size '480x832'
```

### Step 4: Full Pipeline Integration
- [ ] Connect to existing S3 pipeline
- [ ] Test end-to-end workflow
**Test**: Generate and verify upload of test video

## Testing Strategy

### Local Testing (Before RunPod)
1. Environment setup can be tested locally
2. S3 integration can be tested with small files
3. GPU memory requirements can be estimated
4. All setup scripts must be tested and verified locally first
   - [x] setup_env.sh verified locally
   - [x] setup_models.sh verified locally (with dummy files)
   Note: Model loading tests are skipped locally as they require actual model files and CUDA support

### RunPod Testing
1. Test network volume mounting first
2. Verify cached environment restoration
3. Run minimal generation test
4. Test full pipeline

## Checkpoint Recovery
If failure occurs at:
- Step 1: Use cached venv from network volume
- Step 2: Models persist on network volume
- Step 3: Can test with smaller video first
- Step 4: Can test S3 separately

## Resource Requirements
- GPU: A100/H100 (40GB+ VRAM)
- Network Volume: 100GB+
- Base Image: PyTorch 2.0+

## Performance Notes
- Default: 81 frames @ 16 FPS
- VRAM usage: ~35GB for 720p
- Use `offload_model=True` for memory efficiency

### Model Parameters & Performance Notes
- Default video generation: 81 frames at 16 FPS
- Supported resolutions: 
  - 720P (1280x720)
  - 480P (832x480)
  - Square (624x624, 960x960)
- Memory usage:
  - Peak VRAM: ~35GB for 720p generation
  - Recommended to use `offload_model=True` for memory efficiency

### Optimization Tips
1. Use network volume for model storage to avoid re-downloading
2. Pre-warm the instance by loading models once at startup
3. Consider batch processing for multiple generations
4. Monitor VRAM usage and adjust `offload_model` parameter as needed 