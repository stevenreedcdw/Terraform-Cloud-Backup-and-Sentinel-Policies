#!/bin/bash

# Create the necessary directories
mkdir -p backup

# Install dependencies
pip install -r requirements.txt

# Export Terraform Cloud API Token as an environment variable
export TERRAFORM_CLOUD_API_TOKEN="your_terraform_cloud_api_token"

# Run the Python script
python3 backup/tfc_backup_to_s3.py
