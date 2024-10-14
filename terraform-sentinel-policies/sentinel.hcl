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
