
#!/bin/bash

# Create the main repository folder for tfc-backup-to-s3
mkdir -p ../tfc-backup-to-s3
cd ../tfc-backup-to-s3

# Create folders for backup and scripts
mkdir -p backup scripts policies

# Create Python script for Terraform Cloud state backup
cat > backup/tfc_backup_to_s3.py << 'EOF'
import requests
import boto3
import json
import os
from datetime import datetime

# Constants
TERRAFORM_ORG = "your-tfc-organization"
WORKSPACE_NAME = "your-tfc-workspace"
ATLAS_TOKEN = os.getenv("TERRAFORM_CLOUD_API_TOKEN")  # Ensure your API token is set in environment variables
AWS_REGION = "your-aws-region"
S3_BUCKET = "your-s3-bucket-name"
S3_KEY_TEMPLATE = "terraform-backups/{workspace}-{timestamp}.tfstate"

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

# Create Sentinel policy for blocking public CIDR
cat > policies/block_public_cidr.sentinel << 'EOF'
# This policy uses the Sentinel tfplan/v2 import to validate that no security group
# rules have the CIDR "0.0.0.0/0" for egress rules. It covers both the
# aws_security_group and the aws_security_group_rule resources which can both define rules.

# Import the tfplan/v2 import, but use the alias "tfplan"
import "tfplan/v2" as tfplan

# Forbidden CIDRs
forbidden_cidrs = ["0.0.0.0/0"]

# Get all Security Group Egress Rules
SGEgressRules = filter tfplan.resource_changes as address, rc {
  rc.type is "aws_security_group_rule" and
  rc.mode is "managed" and
  (rc.change.actions contains "create" or rc.change.actions contains "update") and
  rc.change.after.type is "egress"
}

# Filter to Egress Security Group Rules with violations
echo "Repository structure and policy files created successfully."