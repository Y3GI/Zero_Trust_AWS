output "vpc_id" {
    description = "The ID of the main application VPC."
    value       = aws_vpc.main.id
}

output "public_subnet_ids" {
    description = "List of IDs for the public subnets (IGW access)."
    value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
    description = "List of IDs for the private subnets (Application tier)."
    value       = [for subnet in aws_subnet.private : subnet.id]
}

output "isolated_subnet_ids" {
    description = "List of IDs for the restricted subnets (Database/Sensitive tier)."
    value       = [for subnet in aws_subnet.isolated : subnet.id]
}