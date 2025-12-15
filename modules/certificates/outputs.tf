output "internal_certificate_arn" {
    description = "ARN of the internal services certificate"
    value       = aws_acm_certificate.internal.arn
}

output "internal_certificate_domain" {
    description = "Domain of the internal certificate"
    value       = aws_acm_certificate.internal.domain_name
}

output "mtls_certificate_arn" {
    description = "ARN of the mTLS certificate"
    value       = aws_acm_certificate.mtls.arn
}

output "mtls_certificate_domain" {
    description = "Domain of the mTLS certificate"
    value       = aws_acm_certificate.mtls.domain_name
}

output "root_ca_arn" {
    description = "ARN of the root Certificate Authority"
    value       = aws_acm_certificate.ca.arn
}

output "root_ca_domain" {
    description = "Domain of the root CA"
    value       = aws_acm_certificate.ca.domain_name
}
