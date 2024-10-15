## Overview
This repository contains a set of Sentinel policies used to enforce governance and compliance in Terraform Cloud.

### Policies
1. **Block Public CIDR (`block_public_cidr.sentinel`)**: Prevents creating or updating resources with the public CIDR `0.0.0.0/0`.
2. **Require Tags (`require_tags.sentinel`)**: Ensures all resources are tagged with specific tags such as `Environment`, `Owner`, and `CostCenter`.
3. **Restrict Resource Types (`restrict_resources.sentinel`)**: Prevents the creation of certain AWS resource types.
4. **EBS Encryption (`ebs_encryption.sentinel`)**: Ensures that all AWS EBS volumes are encrypted.
5. **Allowed EC2 Instance Types (`allowed_instance_types.sentinel`)**: Only allows specific EC2 instance types to be used.

### How to Test Policies
- Mocks are provided to test both success and failure scenarios.
- Use the Sentinel CLI to run tests:

  ```bash
  sentinel test -verbose
