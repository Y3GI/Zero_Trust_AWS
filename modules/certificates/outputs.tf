output "root_ca_arn" {
    description = "ARN of the root Certificate Authority"
    value       = aws_acmpca_certificate_authority.ca.arn
}

output "root_ca_domain" {
    description = "Domain of the root CA"
    value       = aws_acmpca_certificate_authority.ca.certificate_authority_configuration[0].subject[0].common_name
}
