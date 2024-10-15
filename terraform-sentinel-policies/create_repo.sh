#!/bin/bash

# Create the main repository folder
mkdir -p terraform-sentinel-policies
cd terraform-sentinel-policies

# Create folders for policies and mocks
mkdir -p policies mocks/tfplan-v2

# Create the Sentinel policies

# 1. Block Public CIDR Policy
cat > policies/block_public_cidr.sentinel << 'EOF'
import "tfplan/v2" as tfplan

prohibited_cidrs = ["0.0.0.0/0", "::/0"]

is_prohibited_cidr = func(cidr) {
  return cidr in prohibited_cidrs
}

check_resource = func(resource) {
  cidr_attributes = [
    "ingress", "egress", "cidr_blocks",
    "ipv6_cidr_blocks", "cidr_ip", "cidr_ipv6"
  ]

  for attr in cidr_attributes {
    blocks = walk(resource.change.after, attr) else []
    blocks_list = blocks is list ? blocks : [blocks]

    for block in blocks_list {
      if is_prohibited_cidr(block) {
        return true
      }
    }
  }
  return false
}

resource_changes = filter tfplan.resource_changes as rc {
  rc.change.actions contains any ["create", "update"]
}

violations = filter resource_changes as rc {
  check_resource(rc)
}

main = rule {
  length(violations) == 0
}
EOF

# 2. Require Tags Policy
cat > policies/require_tags.sentinel << 'EOF'
import "tfplan/v2" as tfplan

required_tags = ["Environment", "Owner", "CostCenter"]

validate_tags = func(resource) {
  tags = resource.change.after.tags else {}
  missing_tags = difference(required_tags, keys(tags))
  return length(missing_tags) == 0
}

resource_changes = filter tfplan.resource_changes as rc {
  rc.change.actions contains "create" or rc.change.actions contains "update"
}

violations = filter resource_changes as rc {
  not validate_tags(rc)
}

main = rule {
  length(violations) == 0
}
EOF

# 3. Restrict Resource Types Policy
cat > policies/restrict_resources.sentinel << 'EOF'
import "tfplan/v2" as tfplan

disallowed_resource_types = ["aws_db_instance", "aws_redshift_cluster", "aws_elasticsearch_domain"]

is_disallowed_resource = func(resource) {
  return resource.type in disallowed_resource_types
}

new_resources = filter tfplan.resource_changes as rc {
  rc.change.actions contains "create"
}

violations = filter new_resources as resource {
  is_disallowed_resource(resource)
}

main = rule {
  length(violations) == 0
}
EOF

# 4. EBS Encryption Policy
cat > policies/ebs_encryption.sentinel << 'EOF'
import "tfplan/v2" as tfplan

is_encrypted = func(resource) {
  encryption = resource.change.after.encrypted else false
  return encryption == true
}

ebs_volumes = filter tfplan.resource_changes as rc {
  rc.type == "aws_ebs_volume" and
  (rc.change.actions contains "create" or rc.change.actions contains "update")
}

violations = filter ebs_volumes as volume {
  not is_encrypted(volume)
}

main = rule {
  length(violations) == 0
}
EOF

# 5. Allowed Instance Types Policy
cat > policies/allowed_instance_types.sentinel << 'EOF'
import "tfplan/v2" as tfplan

allowed_instance_types = ["t2.micro", "t2.small", "t3.micro", "t3.small"]

is_allowed_instance_type = func(resource) {
  instance_type = resource.change.after.instance_type
  return instance_type in allowed_instance_types
}

ec2_instances = filter tfplan.resource_changes as rc {
  rc.type == "aws_instance" and
  (rc.change.actions contains "create" or rc.change.actions contains "update")
}

violations = filter ec2_instances as instance {
  not is_allowed_instance_type(instance)
}

main = rule {
  length(violations) == 0
}
EOF

# Create the Sentinel mock files for testing

# Mock for passing scenario
cat > mocks/tfplan-v2/mock-tfplan-pass.sentinel << 'EOF'
mock "tfplan/v2" {
  module {
    planned_values = {
      "root_module": {
        "resources": [
          {
            "address": "aws_security_group.example_secure",
            "type": "aws_security_group",
            "values": {
              "ingress": [
                {
                  "cidr_blocks": ["10.0.0.0/16"]  # Compliant ingress rule
                }
              ]
            }
          }
        ]
      }
    }
  }
}
EOF

# Mock for failing scenario
cat > mocks/tfplan-v2/mock-tfplan-fail.sentinel << 'EOF'
mock "tfplan/v2" {
  module {
    planned_values = {
      "root_module": {
        "resources": [
          {
            "address": "aws_security_group.example_public",
            "type": "aws_security_group",
            "values": {
              "ingress": [
                {
                  "cidr_blocks": ["0.0.0.0/0"]  # Violating ingress rule
                }
              ]
            }
          }
        ]
      }
    }
  }
}
EOF

# Create the sentinel.hcl configuration file
cat > sentinel.hcl << 'EOF'
policy "block_public_cidr" {
  source = "policies/block_public_cidr.sentinel"
  enforcement_level = "advisory"
  mock "tfplan/v2" {
    module {
      source = "mocks/tfplan-v2/mock-tfplan-pass.sentinel"
    }
  }
}

policy "require_tags" {
  source = "policies/require_tags.sentinel"
  enforcement_level = "advisory"
  mock "tfplan/v2" {
    module {
      source = "mocks/tfplan-v2/mock-tfplan-pass.sentinel"
    }
  }
}

policy "restrict_resources" {
  source = "policies/restrict_resources.sentinel"
  enforcement_level = "advisory"
  mock "tfplan/v2" {
    module {
      source = "mocks/tfplan-v2/mock-tfplan-pass.sentinel"
    }
  }
}

policy "ebs_encryption" {
  source = "policies/ebs_encryption.sentinel"
  enforcement_level = "advisory"
  mock "tfplan/v2" {
    module {
      source = "mocks/tfplan-v2/mock-tfplan-pass.sentinel"
    }
  }
}

policy "allowed_instance_types" {
  source = "policies/allowed_instance_types.sentinel"
  enforcement_level = "advisory"
  mock "tfplan/v2" {
    module {
      source = "mocks/tfplan-v2/mock-tfplan-pass.sentinel"
    }
  }
}
EOF

# Create README.md file
#cat > README.md << 'EOF'
# Terraform Sentinel Policies Repository

## Overview
This repository contains a set of Sentinel policies used to enforce governance and compliance in Terraform Cloud.

### Policies
#1. **Block Public CIDR (`block_public_cidr.sentinel`)**: Prevents creating or updating resources with the public CIDR `0.0.0.0/0`.
#2. **Require Tags (`require_tags.sentinel`)**: Ensures all resources are tagged with specific tags such as `Environment`, `Owner`, and `CostCenter`.
#3. **Restrict Resource Types (`restrict_resources.sentinel`)**: Prevents the creation of certain AWS resource types.
#4. **EBS Encryption (`ebs_encryption.sentinel`)**: Ensures that all AWS EBS volumes are encrypted.
#5. **Allowed EC2 Instance Types (`allowed_instance_types.sentinel`)**: Only allows specific EC2 instance types to be used.

### How to Test Policies
#- Mocks are provided to test both success and failure scenarios.
#- Use the Sentinel CLI to run tests:

 # ```bash
 # sentinel test -verbose
