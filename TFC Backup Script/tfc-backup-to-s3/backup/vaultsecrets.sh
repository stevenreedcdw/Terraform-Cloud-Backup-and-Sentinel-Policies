vault kv put secret/tfc-backup terraform_org="your-tfc-organization" \
    workspace_name="your-tfc-workspace" \
    terraform_cloud_api_token="your-terraform-cloud-api-token" \
    aws_access_key_id="your-aws-access-key-id" \
    aws_secret_access_key="your-aws-secret-access-key" \
    aws_region="your-aws-region" \
    s3_bucket_name="your-s3-bucket-name"
