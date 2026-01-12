terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# E2E TESTING: RBAC Authorization module (independent)
# Creates IAM policies for bastion and app server roles

module "rbac_authorization" {
    source = "../../../../modules/rbac-authorization"

    env = "e2e-test"
}

output "bastion_policy_arn" {
    value = module.rbac_authorization.bastion_policy_arn
}

output "app_server_policy_arn" {
    value = module.rbac_authorization.app_server_policy_arn
}
