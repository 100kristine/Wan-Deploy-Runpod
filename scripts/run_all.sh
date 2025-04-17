#!/bin/bash
set -e  # Exit on any error

LOG_FILE="/workspace/setup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_step() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

handle_error() {
    local exit_code=$?
    local step=$1
    echo "❌ Error occurred during: $step (Exit code: $exit_code)" | tee -a "$LOG_FILE"
    echo "Check $LOG_FILE for details"
    exit $exit_code
}

# Step 1: Clone repository if not exists
log_step "Step 1: Repository Setup"
if [ ! -d "/workspace/wan_deploy_runpod" ]; then
    log_step "Cloning repository..."
    git clone https://github.com/100kristine/Wan-Deploy-Runpod.git /workspace/wan_deploy_runpod || handle_error "Repository clone"
    cd /workspace/wan_deploy_runpod/scripts || handle_error "Change directory"
else
    log_step "Repository already exists, updating..."
    cd /workspace/wan_deploy_runpod || handle_error "Change directory"
    git pull origin main || handle_error "Git pull"
    cd scripts || handle_error "Change directory to scripts"
fi

# Step 2: Make all scripts executable
log_step "Making scripts executable..."
chmod +x *.sh || handle_error "Make scripts executable"

# Step 3: Run initialization setup
log_step "Step 3: Running initialization setup..."
./init_setup.sh || handle_error "Initialization setup"

# Step 4: Run model setup
log_step "Step 4: Running model setup..."
./setup_models.sh || handle_error "Model setup"

# Step 5: Print completion message and next steps
log_step "✅ All setup steps completed successfully!"
echo "
Setup completed! You can find the full log at: $LOG_FILE

Next steps:
1. Check the log file for any warnings: $LOG_FILE
2. Verify model files are present in /workspace/models/
3. Test the Wan video generation
" 