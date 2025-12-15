terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# AWS Certificate Manager - Certificate for internal services
resource "aws_acm_certificate" "internal" {
    domain_name       = "internal.ztna.local"
    validation_method = "DNS"
    subject_alternative_names = [
        "*.internal.ztna.local",
        "*.services.ztna.local",
        "app.ztna.local",
        "api.ztna.local"
    ]

    tags = merge(var.tags, {
        Name    = "${var.env}-internal-certificate"
        Service = "CertificateManager"
    })

    lifecycle {
        create_before_destroy = true
    }
}

# Certificate for mutual TLS (mTLS) between services
resource "aws_acm_certificate" "mtls" {
    domain_name       = "mtls.ztna.local"
    validation_method = "DNS"
    subject_alternative_names = [
        "*.mtls.ztna.local",
        "service-to-service.ztna.local"
    ]

    tags = merge(var.tags, {
        Name    = "${var.env}-mtls-certificate"
        Service = "CertificateManager"
    })

    lifecycle {
        create_before_destroy = true
    }
}

# Certificate Authority for internal PKI (optional, for advanced ZTNA)
resource "aws_acmpca_certificate_authority" "ca" {
    certificate_authority_configuration {
        key_algorithm     = "RSA_2048"
        signing_algorithm = "SHA256WITHRSA"
        subject {
            common_name = "ca.ztna.local"
        }
    }

    tags = merge(var.tags, {
        Name    = "${var.env}-root-ca"
        Service = "CertificateManager"
    })
}

# Activate the root CA
resource "aws_acmpca_certificate_authority_certificate" "ca" {
    certificate_authority_arn             = aws_acmpca_certificate_authority.ca.arn
    certificate                           = aws_acmpca_certificate_authority.ca.certificate
    certificate_chain                     = aws_acmpca_certificate_authority.ca.certificate_chain
}
