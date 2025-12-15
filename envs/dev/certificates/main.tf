provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

module "certificates" {
    source = "../../../modules/certificates"

    env = "dev"
}

output "internal_certificate_arn" {
    value = module.certificates.internal_certificate_arn
}

output "mtls_certificate_arn" {
    value = module.certificates.mtls_certificate_arn
}

output "root_ca_arn" {
    value = module.certificates.root_ca_arn
}
