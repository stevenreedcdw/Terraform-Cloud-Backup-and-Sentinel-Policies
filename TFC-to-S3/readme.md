# Terraform Cloud State Backup Script

This script automates the process of backing up state files from Terraform Cloud workspaces to an AWS S3 bucket. It retrieves sensitive information, such as API tokens and AWS credentials, from HashiCorp Vault, and uses this information to back up the Terraform state files.

## Prerequisites

Before running the script, ensure you have the following set up:

1. **HashiCorp Vault**: Ensure your Vault is running and you have stored your secrets in the path `secret/tfc-backup`.
2. **AWS CLI**: The AWS CLI should be installed and configured on the machine where the script will run.
3. **jq**: The `jq` utility is used for processing JSON in Bash. Install it if not already present:
   ```bash
   sudo apt-get install jq  # For Debian/Ubuntu
   brew install jq          # For MacOS

##Setup
Vault Configuration
The following secrets should be stored in the specified Vault path (secret/tfc-backup):

terraform_org: The name of your Terraform Cloud organization.
terraform_cloud_api_token: API token for accessing Terraform Cloud.
aws_access_key_id: AWS Access Key ID.
aws_secret_access_key: AWS Secret Access Key.
aws_region: AWS region for your S3 bucket.
s3_bucket_name: Name of the AWS S3 bucket to store the backups.
AWS S3 Bucket
Ensure that the S3 bucket where backups will be stored exists. If not, create one in your AWS account and make note of the bucket name.

##Script Usage
Clone the repository or copy the script to your local machine.

**Make the script executable:

bash
Copy code
chmod +x backup-terraform-cloud.sh
Update the script with your Vault and Terraform details:

Replace https://your-vault-address with your actual Vault server's URL.
Replace your-vault-token with your actual Vault token.
Ensure the secret path secret/tfc-backup in Vault contains the necessary credentials.
Step-by-Step Execution
Retrieve credentials from HashiCorp Vault: The script retrieves credentials from the Vault secret path and parses them using jq to extract necessary details like terraform_org, terraform_cloud_api_token, aws_access_key_id, aws_secret_access_key, aws_region, and s3_bucket_name.

Configure AWS CLI with the retrieved credentials: The AWS CLI is configured using the credentials retrieved from Vault.

**

## Prerequisites

Before running the script, ensure you have the following set up:

1. **HashiCorp Vault**: Ensure your Vault is running and you have stored your secrets in the path `secret/tfc-backup`.
2. **AWS CLI**: The AWS CLI should be installed and configured on the machine where the script will run.
3. **jq**: The `jq` utility is used for processing JSON in Bash. Install it if not already present:
   ```bash
   sudo apt-get install jq  # For Debian/Ubuntu
   brew install jq          # For macOS

## Setup
Vault Configuration
Ensure that the following secrets are stored in the specified Vault path (secret/tfc-backup):

terraform_org: The name of your Terraform Cloud organization.
**terraform_cloud_api_token**: API token for accessing Terraform Cloud.
**aws_access_key_id**: AWS Access Key ID.
**aws_secret_access_key**: AWS Secret Access Key.
**aws_region**: AWS region for your S3 bucket.
**s3_bucket_name**: Name of the AWS S3 bucket to store the backups.

AWS S3 Bucket
Ensure that the S3 bucket where backups will be stored exists. If not, create one in your AWS account and note the bucket name.

## Script Usage
Clone the repository or copy the script to your local machine.

Make the script executable:

```
 bash
Copy code
chmod +x backup-terraform-cloud.sh
Update the script with your Vault and Terraform Cloud details:
```

Replace https://your-vault-address with your actual Vault server's URL.
Replace your-vault-token with your actual Vault token.
Ensure the secret path secret/tfc-backup in Vault contains the necessary credentials (Terraform Cloud organization name, API token, AWS credentials, and S3 bucket details).
Step-by-Step Instructions
Retrieve credentials from HashiCorp Vault:

The script retrieves credentials from Vault by accessing the secret path secret/tfc-backup. It uses the vault kv get command to fetch the secrets in JSON format. The secrets include the Terraform Cloud organization name, API token, AWS credentials, and S3 bucket name.

The retrieved values are parsed using jq to extract the required fields.


```
bash
Copy code
export VAULT_ADDR="https://your-vault-address"
export VAULT_TOKEN="your-vault-token"
SECRETS=$(vault kv get -format=json secret/tfc-backup)
Configure AWS CLI with the retrieved credentials:
```

The AWS CLI is configured using the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION values retrieved from Vault. These values are exported as environment variables to ensure that subsequent AWS CLI commands use the correct credentials.

```
bash
Copy code
export AWS_ACCESS_KEY_ID=$(echo ${SECRETS} | jq -r '.data.data.aws_access_key_id')
export AWS_SECRET_ACCESS_KEY=$(echo ${SECRETS} | jq -r '.data.data.aws_secret_access_key')
export AWS_REGION=$(echo ${SECRETS} | jq -r '.data.data.aws_region')
Get all workspaces for the Terraform Cloud organization:
```

The script retrieves all the workspaces in the specified Terraform Cloud organization by making an API call to Terraform Cloud's workspace endpoint. The API token is used for authentication, and the organization name is passed as part of the API URL.

The names of the workspaces are extracted using jq.

```
bash
Copy code
WORKSPACES=$(curl -s \
  -H "Authorization: Bearer ${ATLAS_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces" | jq -r '.data[] | .attributes.name')
Loop through each workspace and back up the state file:

For each workspace, the script retrieves the latest state file URL by making an API call to Terraform Cloud. If the state file is available, it downloads the state file and saves it locally. The state file is then uploaded to the specified S3 bucket using the AWS CLI.

The state file is named using the workspace name and the current timestamp for uniqueness. After uploading the state file to S3, the local copy is deleted to free up space.
```

```
bash
Copy code
for WORKSPACE_NAME in ${WORKSPACES}; do
  echo "Processing workspace: ${WORKSPACE_NAME}"

  STATE_FILE_URL=$(curl -s \
    -H "Authorization: Bearer ${ATLAS_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/organizations/${TERRAFORM_ORG}/workspaces/${WORKSPACE_NAME}/current-state-version" | jq -r '.data.attributes["hosted-state-download-url"]')

  if [[ -z "$STATE_FILE_URL" || "$STATE_FILE_URL" == "null" ]]; then
    echo "Warning: Failed to get state file URL for workspace ${WORKSPACE_NAME}. Skipping."
    continue
  fi

  curl -s -H "Authorization: Bearer ${ATLAS_TOKEN}" -o "${WORKSPACE_NAME}.tfstate" "${STATE_FILE_URL}"

  if [[ ! -f "${WORKSPACE_NAME}.tfstate" ]]; then
    echo "Warning: Failed to download state file for workspace ${WORKSPACE_NAME}. Skipping."
    continue
  fi

  S3_KEY="terraform-backups/${WORKSPACE_NAME}-$(date +%Y-%m-%d_%H-%M-%S).tfstate"
  aws s3 cp "${WORKSPACE_NAME}.tfstate" s3://${AWS_S3_BUCKET}/${S3_KEY} --region ${AWS_REGION}

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to upload state file for workspace ${WORKSPACE_NAME} to S3."
  else
    echo "Successfully uploaded state file for workspace ${WORKSPACE_NAME} to s3://${AWS_S3_BUCKET}/${S3_KEY}"
  fi

  rm -f "${WORKSPACE_NAME}.tfstate"
done
```

##Error Handling
The script contains error handling to ensure that if any step fails, the script logs a meaningful message and continues with the next workspace. It also ensures that sensitive data like credentials are not printed in the logs.
