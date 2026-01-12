terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the secrets module to be tested independently
# without requiring Security module to be deployed first
locals {
    # Mock Security values
    mock_kms_key_id           = "arn:aws:kms:eu-north-1:000000000000:key/mock-integration-test-key"
    mock_app_instance_role_arn = "arn:aws:iam::000000000000:role/mock-integration-test-app-role"
}

module "secrets" {
    source = "../../../../modules/secrets"

    env                     = "integration-test"
    region                  = "eu-north-1"
    
    # Use mock security values for isolated testing
    kms_key_id              = local.mock_kms_key_id
    app_instance_role_arn   = local.mock_app_instance_role_arn

    # Test credentials (use defaults from variables.tf)
    db_password             = var.db_password
    api_key_1               = var.api_key_1
    api_key_2               = var.api_key_2
    
    db_username             = "appuser"
    db_host                 = "localhost"
    db_port                 = 5432
    db_name                 = "ztna_db"
}

output "db_credentials_secret_arn" {
    value = module.secrets.db_credentials_secret_arn
}

output "api_keys_secret_arn" {
    value = module.secrets.api_keys_secret_arn
}

