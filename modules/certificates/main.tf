terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

# Certificate Authority for internal PKI
# This CA is used for ZTNA certificate issuance
resource "aws_acmpca_certificate_authority" "ca" {
    certificate_authority_configuration {
        key_algorithm     = "RSA_2048"
        signing_algorithm = "SHA256WITHRSA"
        subject {
            common_name = "ca.ztna.local"
        }
    }

    permanent_deletion_time_in_days = 7

    tags = merge(var.tags, {
        Name    = "${var.env}-root-ca"
        Service = "CertificateManager"
    })
}

# Note: ACM public certificates (internal, mtls) require email/DNS validation
# For dev environment, these are omitted. In production:
# - Use AWS Certificate Manager with DNS validation
# - Automate DNS record creation with Route53
# - Use aws_acm_certificate resource with validation implementation
