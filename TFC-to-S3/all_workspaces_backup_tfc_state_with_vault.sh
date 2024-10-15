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
ATLAS_TOKEN=$(echo ${SECRETS} | jq -r '.data.data.terraform_cloud_api_token')
AWS_ACCESS_KEY_ID=$(echo ${SECRETS} | jq -r '.data.data.aws_access_key_id')
AWS_SECRET_ACCESS_KEY=$(echo ${SECRETS} | jq -r '.data.data.aws_secret_access_key')
AWS_REGION=$(echo ${SECRETS} | jq -r '.data.data.aws_region')
AWS_S3_BUCKET=$(echo ${SECRETS} | jq -r '.data.data.s3_bucket_name')

# Step 2: Configure AWS CLI with the retrieved credentials
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_REGION=${AWS_REGION}

# Step 3: Get all workspaces for the organization
WORKSPACES=$(curl -s \
  -H "Authorization: Bearer ${ATLAS_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces" | jq -r '.data[] | .attributes.name')

if [[ -z "$WORKSPACES" ]]; then
  echo "Error: Failed to retrieve workspaces from Terraform Cloud."
  exit 1
fi

# Step 4: Loop through each workspace and back up the state file
for WORKSPACE_NAME in ${WORKSPACES}; do
  echo "Processing workspace: ${WORKSPACE_NAME}"

  # Get the latest state file URL from Terraform Cloud
  STATE_FILE_URL=$(curl -s \
    -H "Authorization: Bearer ${ATLAS_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces/${WORKSPACE_NAME}/current-state-version" | jq -r '.data.attributes["hosted-state-download-url"]')

  if [[ -z "$STATE_FILE_URL" || "$STATE_FILE_URL" == "null" ]]; then
    echo "Warning: Failed to get state file URL for workspace ${WORKSPACE_NAME}. Skipping."
    continue
  fi

  # Download the state file
  curl -s -H "Authorization: Bearer ${ATLAS_TOKEN}" -o "${WORKSPACE_NAME}.tfstate" "${STATE_FILE_URL}"

  if [[ ! -f "${WORKSPACE_NAME}.tfstate" ]]; then
    echo "Warning: Failed to download state file for workspace ${WORKSPACE_NAME}. Skipping."
    continue
  fi

  # Upload the state file to S3
  S3_KEY="terraform-backups/${WORKSPACE_NAME}-$(date +%Y-%m-%d_%H-%M-%S).tfstate"
  aws s3 cp "${WORKSPACE_NAME}.tfstate" s3://${AWS_S3_BUCKET}/${S3_KEY} --region ${AWS_REGION}

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to upload state file for workspace ${WORKSPACE_NAME} to S3."
  else
    echo "Successfully uploaded state file for workspace ${WORKSPACE_NAME} to s3://${AWS_S3_BUCKET}/${S3_KEY}"
  fi

  # Cleanup downloaded file
  rm -f "${WORKSPACE_NAME}.tfstate"
done