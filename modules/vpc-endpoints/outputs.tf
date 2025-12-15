# S3 VPC Endpoint Output
output "s3_vpc_endpoint_id" {
    description = "The ID of the S3 VPC Endpoint"
    value       = aws_vpc_endpoint.s3.id
}

# Secrets Manager VPC Endpoint Output
output "secretsmanager_vpc_endpoint_id" {
    description = "The ID of the Secrets Manager VPC Endpoint"
    value       = aws_vpc_endpoint.secretsmanager.id
}

output "secretsmanager_vpc_endpoint_dns" {
    description = "The DNS name of the Secrets Manager VPC Endpoint"
    value       = aws_vpc_endpoint.secretsmanager.dns_entry[0].dns_name
}

# Systems Manager VPC Endpoint Outputs
output "ssm_vpc_endpoint_id" {
    description = "The ID of the Systems Manager VPC Endpoint"
    value       = aws_vpc_endpoint.ssm.id
}

output "ec2messages_vpc_endpoint_id" {
    description = "The ID of the EC2 Messages VPC Endpoint"
    value       = aws_vpc_endpoint.ec2messages.id
}

output "ssmmessages_vpc_endpoint_id" {
    description = "The ID of the SSM Messages VPC Endpoint"
    value       = aws_vpc_endpoint.ssmmessages.id
}

# STS VPC Endpoint Output
output "sts_vpc_endpoint_id" {
    description = "The ID of the STS VPC Endpoint"
    value       = aws_vpc_endpoint.sts.id
}

# CloudWatch Logs VPC Endpoint Output
output "logs_vpc_endpoint_id" {
    description = "The ID of the CloudWatch Logs VPC Endpoint"
    value       = aws_vpc_endpoint.logs.id
}

# KMS VPC Endpoint Output
output "kms_vpc_endpoint_id" {
    description = "The ID of the KMS VPC Endpoint"
    value       = aws_vpc_endpoint.kms.id
}

# Security Group Output
output "vpc_endpoints_security_group_id" {
    description = "The ID of the security group for VPC endpoints"
    value       = aws_security_group.vpc_endpoints.id
}
