provider "aws" {

    region  = "eu-north-1"
}

# Get outputs from security module
data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

module "secrets" {
    source = "../../../modules/secrets"

    env                     = "dev"
    region                  = "eu-north-1"
    kms_key_id              = try(data.terraform_remote_state.security.outputs.kms_key_id, "arn:aws:kms:eu-north-1:000000000000:key/destroyed")
    app_instance_role_arn   = try(data.terraform_remote_state.security.outputs.app_instance_role_arn, "arn:aws:iam::000000000000:role/destroyed")

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
