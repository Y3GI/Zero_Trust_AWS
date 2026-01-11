terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# No external dependencies required - rbac-authorization is self-contained
module "rbac_authorization" {
    source = "../../../modules/rbac-authorization"

    env = "dev"
}

output "bastion_policy_arn" {
    value = module.rbac_authorization.bastion_policy_arn
}

output "app_server_policy_arn" {
    value = module.rbac_authorization.app_server_policy_arn
}
