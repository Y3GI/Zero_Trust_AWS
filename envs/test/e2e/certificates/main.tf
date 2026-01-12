terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# E2E TESTING: Certificates module (independent)
# Creates ACM Private Certificate Authority

module "certificates" {
    source = "../../../../modules/certificates"

    env = "e2e-test"
}

output "root_ca_arn" {
    value = module.certificates.root_ca_arn
}
