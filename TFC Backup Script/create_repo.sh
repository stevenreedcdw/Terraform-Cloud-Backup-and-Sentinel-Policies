#!/bin/bash

# Create the main repository folder
mkdir -p tfc-backup-to-s3
cd tfc-backup-to-s3

# Create folders for backup and scripts
mkdir -p backup scripts

# Create Python script for Terraform Cloud state backup
cat > backup/tfc_backup_to_s3.py << 'EOF'
import requests
import boto3
import hvac
import os
from datetime import datetime

# Constants
VAULT_ADDR = os.getenv("VAULT_ADDR")  # Vault address, e.g., https://vault.example.com
VAULT_TOKEN = os.getenv("VAULT_TOKEN")  # Vault token for authentication
VAULT_SECRET_PATH = "secret/tfc-backup"  # Path in Vault where the secrets are stored

# Initialize the Vault client
client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

# Read secrets from Vault
try:
    vault_secrets = client.secrets.kv.v2.read_secret_version(path=VAULT_SECRET_PATH)
    secrets_data = vault_secrets["data"]["data"]

    # Pull values from Vault
    TERRAFORM_ORG = secrets_data.get("terraform_org")
    WORKSPACE_NAME = secrets_data.get("workspace_name")
    ATLAS_TOKEN = secrets_data.get("terraform_cloud_api_token")
    AWS_REGION = secrets_data.get("aws_region")
    S3_BUCKET = secrets_data.get("s3_bucket_name")
    S3_KEY_TEMPLATE = "terraform-backups/{workspace}-{timestamp}.tfstate"
except Exception as e:
    raise Exception(f"Failed to fetch secrets from Vault: {str(e)}")

# Initialize AWS S3 client
s3_client = boto3.client("s3", region_name=AWS_REGION)

def fetch_latest_state_version_id():
    url = f"https://app.terraform.io/api/v2/organizations/{TERRAFORM_ORG}/workspaces/{WORKSPACE_NAME}/current-state-version"
    headers = {
        "Authorization": f"Bearer {ATLAS_TOKEN}",
        "Content-Type": "application/vnd.api+json"
    }
    
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        state_version_data = response.json()
        return state_version_data['data']['id']
    else:
        raise Exception(f"Failed to fetch state version ID: {response.status_code} - {response.text}")

def download_state_file(state_version_id):
    url = f"https://app.terraform.io/api/v2/state-versions/{state_version_id}/download"
    headers = {
        "Authorization": f"Bearer {ATLAS_TOKEN}"
    }
    
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.content
    else:
        raise Exception(f"Failed to download state file: {response.status_code} - {response.text}")

def upload_state_to_s3(state_file_content):
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    s3_key = S3_KEY_TEMPLATE.format(workspace=WORKSPACE_NAME, timestamp=timestamp)

    try:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=state_file_content,
            ContentType="application/json"
        )
        print(f"Successfully uploaded state file to s3://{S3_BUCKET}/{s3_key}")
    except Exception as e:
        raise Exception(f"Failed to upload to S3: {str(e)}")

def main():
    try:
        state_version_id = fetch_latest_state_version_id()
        print(f"Fetched state version ID: {state_version_id}")
        
        state_file_content = download_state_file(state_version_id)
        print(f"Downloaded state file for workspace: {WORKSPACE_NAME}")
        
        upload_state_to_s3(state_file_content)
    except Exception as e:
        print(f"Error occurred: {str(e)}")

if __name__ == "__main__":
    main()
EOF

# Create requirements.txt for dependencies
cat > requirements.txt << 'EOF'
boto3
requests
hvac
EOF

# Create Shell script for Linux/macOS users
cat > scripts/create_folders_and_run.sh << 'EOF'
#!/bin/bash

# Create the necessary directories
mkdir -p backup

# Install dependencies
pip install -r requirements.txt

# Export Terraform Cloud API Token as an environment variable
export TERRAFORM_CLOUD_API_TOKEN="your_terraform_cloud_api_token"

# Run the Python script
python3 backup/tfc_backup_to_s3.py
EOF

# Make the created Shell script executable
chmod +x scripts/create_folders_and_run.sh

# Create README.md file
#cat > README.md << 'EOF'
# Terraform Cloud Backup to S3

## Overview

#This repository contains scripts to automate the backup of Terraform Cloud (TFC) state files to an AWS S3 bucket. The Python script interacts with Terraform Cloud's API to download the latest state file and then uploads it to an S3 bucket for secure storage.

### Repository Structure

