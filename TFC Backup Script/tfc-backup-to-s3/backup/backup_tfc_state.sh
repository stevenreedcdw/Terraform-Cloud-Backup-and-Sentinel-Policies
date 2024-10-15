#!/bin/bash

# Variables
TERRAFORM_ORG="your-tfc-organization"
WORKSPACE_NAME="your-tfc-workspace"
ATLAS_TOKEN="your-terraform-cloud-api-token"
AWS_S3_BUCKET="your-s3-bucket-name"
AWS_REGION="your-aws-region"
S3_KEY_TEMPLATE="terraform-backups/${WORKSPACE_NAME}-$(date +%Y-%m-%d_%H-%M-%S).tfstate"

# Download the latest state file from Terraform Cloud
STATE_FILE_URL=$(curl -s \
  -H "Authorization: Bearer ${ATLAS_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces/${WORKSPACE_NAME}/current-state-version" | jq -r '.data.attributes["hosted-state-download-url"]')

if [[ -z "$STATE_FILE_URL" || "$STATE_FILE_URL" == "null" ]]; then
  echo "Error: Failed to get state file URL from Terraform Cloud."
  exit 1
fi

# Download the state file
curl -s -H "Authorization: Bearer ${ATLAS_TOKEN}" -o latest.tfstate "${STATE_FILE_URL}"

if [[ ! -f "latest.tfstate" ]]; then
  echo "Error: Failed to download state file."
  exit 1
fi

# Upload the state file to S3
aws s3 cp latest.tfstate s3://${AWS_S3_BUCKET}/${S3_KEY_TEMPLATE} --region ${AWS_REGION}

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to upload state file to S3."
  exit 1
else
  echo "Successfully uploaded state file to s3://${AWS_S3_BUCKET}/${S3_KEY_TEMPLATE}"
fi

# Cleanup downloaded file
rm -f latest.tfstate
