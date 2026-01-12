terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# INTEGRATION TESTING: Certificates module deployed independently
# Creates ACM Private Certificate Authority

module "certificates" {
    source = "../../../../modules/certificates"

    env = "integration-test"
}

output "root_ca_arn" {
    value = module.certificates.root_ca_arn
}
