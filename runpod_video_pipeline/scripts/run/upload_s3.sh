#!/bin/bash
set -e

# Load environment variables from .env if it exists
if [[ -f .env ]]; then
    echo "Loading environment variables from .env..."
    # Only export valid variable assignments, ignore comments and empty lines
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        # Export the variable
        export "$line"
    done < .env
else
    echo "Note: No .env file found. Using environment variables from system."
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Required environment variables
required_vars=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
    "S3_BUCKET_NAME"
)

# Check for required environment variables
missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Error: Missing required environment variables:"
    printf '%s\n' "${missing_vars[@]}"
    echo ""
    echo "Please ensure these variables are set either in your environment or in .env file."
    echo "Current values:"
    echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-(not set)}"
    echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:+******}"
    echo "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-(not set)}"
    echo "S3_BUCKET_NAME=${S3_BUCKET_NAME:-(not set)}"
    exit 1
fi

# Help message
show_help() {
    echo "Usage: upload_s3.sh [options] <file_or_directory>"
    echo ""
    echo "Options:"
    echo "  -p, --prefix   S3 prefix/folder (default: $S3_DEFAULT_PREFIX)"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Environment variables (set in .env or system):"
    echo "  AWS_ACCESS_KEY_ID"
    echo "  AWS_SECRET_ACCESS_KEY"
    echo "  AWS_DEFAULT_REGION"
    echo "  S3_BUCKET_NAME"
    echo "  S3_DEFAULT_PREFIX (optional)"
}

# Default values
PREFIX="${S3_DEFAULT_PREFIX:-wan_videos/}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            SOURCE="$1"
            shift
            ;;
    esac
done

# Validate input
if [[ -z "$SOURCE" ]]; then
    echo "Error: No source file or directory specified"
    show_help
    exit 1
fi

# Test AWS credentials with detailed error output
echo "Testing AWS credentials..."
if ! aws_identity=$(aws sts get-caller-identity 2>&1); then
    echo "Error: AWS credentials issue detected."
    echo "Error details: $aws_identity"
    echo ""
    echo "To fix this:"
    echo "1. Check your credentials in AWS Console -> IAM -> Users -> Your User -> Security credentials"
    echo "2. You might need to create new access keys if these are expired"
    echo "3. Ensure your IAM user has the following permissions:"
    echo "   - s3:PutObject"
    echo "   - s3:ListBucket"
    echo ""
    exit 1
fi

# Show current identity (helpful for debugging)
echo "Using AWS identity:"
echo "$aws_identity"
echo ""

# Test bucket access with detailed error output
echo "Testing S3 bucket access..."
if ! bucket_test=$(aws s3 ls "s3://$S3_BUCKET_NAME" 2>&1); then
    echo "Error: S3 bucket access failed"
    echo "Error details: $bucket_test"
    echo ""
    echo "Required S3 permissions for bucket '$S3_BUCKET_NAME':"
    echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::'$S3_BUCKET_NAME'",
                "arn:aws:s3:::'$S3_BUCKET_NAME'/*"
            ]
        }
    ]
}'
    echo ""
    echo "You can add these permissions in:"
    echo "AWS Console -> IAM -> Users -> Your User -> Add permissions -> Create inline policy"
    exit 1
fi

# Function to get clean S3 URL
get_s3_url() {
    local file_path=$1
    local bucket=$S3_BUCKET_NAME
    local region=$AWS_DEFAULT_REGION
    local prefix=${S3_DEFAULT_PREFIX:-}
    
    # Clean up the prefix (remove any trailing comments)
    prefix=$(echo "$prefix" | tr -d ' \t\n\r')
    
    # Construct the URL
    echo "https://${bucket}.s3.${region}.amazonaws.com/${prefix}${file_path##*/}"
}

# Upload the file
echo "Uploading to s3://$S3_BUCKET_NAME/$S3_DEFAULT_PREFIX..."
if aws s3 cp "$SOURCE" "s3://$S3_BUCKET_NAME/$S3_DEFAULT_PREFIX"; then
    url=$(get_s3_url "$SOURCE")
    echo "✓ Upload complete! File available at:"
    echo "$url"
    
    # Test if the file is publicly accessible
    echo -n "Testing public access... "
    if curl -s -I "$url" | grep -q "200 OK"; then
        echo "✓ File is publicly accessible!"
    else
        echo "✗ File is not publicly accessible."
        echo ""
        echo "To make files publicly accessible, you need to:"
        echo "1. Go to AWS Console → S3 → $S3_BUCKET_NAME → Permissions"
        echo "2. Under 'Bucket Policy', add this policy (replace $S3_BUCKET_NAME with your bucket name):"
        echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::'$S3_BUCKET_NAME'/*"
        }
    ]
}'
        echo ""
        echo "3. Make sure bucket settings are configured correctly:"
        echo "   - Object Ownership: 'Bucket owner enforced'"
        echo "   - Block Public Access: All settings OFF"
    fi
else
    echo "✗ Upload failed!"
    exit 1
fi 