output "vpc_id" {
    description = "The ID of the main application VPC."
    value       = aws_vpc.main.id
}

output "public_subnet_ids" {
    description = "List of IDs for the public subnets (IGW access)."
    value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
    description = "List of IDs for the private subnets (Application tier)."
    value       = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
    description = "List of IDs for the restricted subnets (Database/Sensitive tier)."
    value       = aws_subnet.isolated[*].id
}