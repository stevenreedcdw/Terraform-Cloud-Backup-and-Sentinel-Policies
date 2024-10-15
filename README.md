# Terraform Cloud Sentinel Policies and Backup Script

## Overview

This repository contains:

1. **Terraform Cloud Sentinel Policies**: Sentinel policies that enforce governance and compliance rules within Terraform Cloud.
2. **Terraform Cloud State Backup Script**: A Bash script that backs up Terraform Cloud state files to an AWS S3 bucket. The script uses HashiCorp Vault to securely fetch sensitive credentials and AWS CLI to upload the state file to S3.

### Repository Structure


- **policies/**: Contains all the Sentinel policies that enforce rules for Terraform Cloud.
- **mocks/**: Contains mock data for testing Sentinel policies.
- **scripts/**: Contains the backup script to download and back up Terraform Cloud state files to AWS S3.
- **README.md**: Instructions for using the repository.

---

## Part 1: Terraform Cloud Sentinel Policies

### Overview

The **Sentinel Policies** in this repository enforce a set of best practices and compliance rules within Terraform Cloud, ensuring infrastructure is deployed securely and with governance in place.

### Policies Included

1. **Block Public CIDR (`block_public_cidr.sentinel`)**: Prevents creating or updating resources with the public CIDR `0.0.0.0/0`.
2. **Require Tags (`require_tags.sentinel`)**: Ensures all resources are tagged with specific tags like `Environment`, `Owner`, and `CostCenter`.
3. **Restrict Resource Types (`restrict_resources.sentinel`)**: Prevents the creation of specific AWS resource types like `aws_db_instance` and `aws_redshift_cluster`.
4. **EBS Encryption (`ebs_encryption.sentinel`)**: Ensures that all AWS EBS volumes are encrypted.
5. **Allowed EC2 Instance Types (`allowed_instance_types.sentinel`)**: Only allows specific EC2 instance types to be used.

### How to Test Policies

Mocks are provided to test both success and failure scenarios for the policies. You can use the **Sentinel CLI** to run tests.

#### Steps:

1. **Install Sentinel CLI**:
   - Follow the [Sentinel installation guide](https://docs.hashicorp.com/sentinel/downloads) to install the Sentinel CLI on your machine.

2. **Run the Tests**:
   - Navigate to the repository directory where the Sentinel policies and mocks are located.
   - Run the tests using the Sentinel CLI:
     ```bash
     sentinel test -verbose
     ```
   - This command will run the Sentinel tests using the mock data provided in the `mocks/tfplan-v2/` folder.

---

## Part 2: Terraform Cloud State Backup Script

### Overview

The **Terraform Cloud State Backup Script** backs up the latest state file from a Terraform Cloud workspace to an AWS S3 bucket. It securely retrieves credentials from **HashiCorp Vault** and uses the **AWS CLI** to upload the state file to S3.

### Prerequisites

1. **Terraform Cloud API Token**: You'll need an API token from Terraform Cloud with read access to the state file.
2. **AWS S3 Bucket**: Ensure you have an S3 bucket to store the state backups.
3. **HashiCorp Vault**: Secrets like your Terraform Cloud API token and AWS credentials should be stored securely in Vault.
4. **Vault CLI**: Install the [Vault CLI](https://learn.hashicorp.com/tutorials/vault/getting-started-install) to interact with HashiCorp Vault.
5. **AWS CLI**: Install and configure the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) to upload the state file to your S3 bucket.
6. **jq**: Install `jq` to process JSON responses.

### Step-by-Step Instructions

#### 1. Store Secrets in Vault

Store the necessary credentials in HashiCorp Vault. The example below stores Terraform Cloud and AWS credentials in the `secret/tfc-backup` path: 

vault kv put secret/tfc-backup terraform_org="your-tfc-organization" \
    workspace_name="your-tfc-workspace" \
    terraform_cloud_api_token="your-terraform-cloud-api-token" \
    aws_access_key_id="your-aws-access-key-id" \
    aws_secret_access_key="your-aws-secret-access-key" \
    aws_region="your-aws-region" \
    s3_bucket_name="your-s3-bucket-name"

Setup Environment Variables
Export your Vault environment variables to authenticate with Vault:

**export VAULT_ADDR="https://your-vault-address"
**export VAULT_TOKEN="your-vault-token"

Make the Script Executable
Make the backup_tfc_state_with_vault.sh script executable:
**chmod +x scripts/backup_tfc_state_with_vault.sh

##Run the Backup Script
Run the script to back up the latest Terraform Cloud state file to your S3 bucket:
**./scripts/backup_tfc_state_with_vault.sh

##Automate Backups with Cron
To automate backups, set up a cron job that runs the script at regular intervals. For example, to back up the state every day at midnight:
**0 0 * * * /path/to/scripts/backup_tfc_state_with_vault.sh >> /path/to/backup_log.txt 2>&1

##Detailed Script Breakdown Backup Script (backup_tfc_state_with_vault.sh)
#!/bin/bash

# Constants
VAULT_ADDR="https://your-vault-address"
VAULT_TOKEN="your-vault-token"
VAULT_SECRET_PATH="secret/tfc-backup"

# Step 1: Retrieve credentials from HashiCorp Vault
export VAULT_ADDR=${VAULT_ADDR}
export VAULT_TOKEN=${VAULT_TOKEN}

# Fetch secrets from Vault
SECRETS=$(vault kv get -format=json ${VAULT_SECRET_PATH})

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to retrieve secrets from Vault."
  exit 1
fi

# Parse the necessary secrets
TERRAFORM_ORG=$(echo ${SECRETS} | jq -r '.data.data.terraform_org')
WORKSPACE_NAME=$(echo ${SECRETS} | jq -r '.data.data.workspace_name')
ATLAS_TOKEN=$(echo ${SECRETS} | jq -r '.data.data.terraform_cloud_api_token')
AWS_ACCESS_KEY_ID=$(echo ${SECRETS} | jq -r '.data.data.aws_access_key_id')
AWS_SECRET_ACCESS_KEY=$(echo ${SECRETS} | jq -r '.data.data.aws_secret_access_key')
AWS_REGION=$(echo ${SECRETS} | jq -r '.data.data.aws_region')
AWS_S3_BUCKET=$(echo ${SECRETS} | jq -r '.data.data.s3_bucket_name')

# Step 2: Configure AWS CLI with the retrieved credentials
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_REGION=${AWS_REGION}

# Step 3: Get the latest state file URL from Terraform Cloud
STATE_FILE_URL=$(curl -s \
  -H "Authorization: Bearer ${ATLAS_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces/${WORKSPACE_NAME}/current-state-version" | jq -r '.data.attributes["hosted-state-download-url"]')

if [[ -z "$STATE_FILE_URL" || "$STATE_FILE_URL" == "null" ]]; then
  echo "Error: Failed to get state file URL from Terraform Cloud."
  exit 1
fi

# Step 4: Download the state file
curl -s -H "Authorization: Bearer ${ATLAS_TOKEN}" -o latest.tfstate "${STATE_FILE_URL}"

if [[ ! -f "latest.tfstate" ]]; then
  echo "Error: Failed to download state file."
  exit 1
fi

# Step 5: Upload the state file to S3
S3_KEY="terraform-backups/${WORKSPACE_NAME}-$(date +%Y-%m-%d_%H-%M-%S).tfstate"
aws s3 cp latest.tfstate s3://${AWS_S3_BUCKET}/${S3_KEY} --region ${AWS_REGION}

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to upload state file to S3."
  exit 1
else
  echo "Successfully uploaded state file to s3://${AWS_S3_BUCKET}/${S3_KEY}"
fi

# Step 6: Cleanup downloaded file
rm -f latest.tfstate


