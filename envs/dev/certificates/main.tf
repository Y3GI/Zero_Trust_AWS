provider "aws" {

    region  = "eu-north-1"
}

module "certificates" {
    source = "../../../modules/certificates"

    env = "dev"
}

output "root_ca_arn" {
    value = module.certificates.root_ca_arn
}
