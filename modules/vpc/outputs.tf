# VPC Outputs
output "vpc_id" {
    description = "The ID of the main application VPC."
    value       = aws_vpc.main.id
}

output "vpc_arn" {
    description = "The ARN of the main application VPC."
    value       = aws_vpc.main.arn
}

output "vpc_cidr" {
    description = "The CIDR block of the main application VPC."
    value       = aws_vpc.main.cidr_block
}

# Subnet Outputs
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

# Route Table Outputs
output "public_rt_id" {
    description = "ID of the public route table."
    value       = aws_route_table.public_rt.id
}

output "private_rt_id" {
    description = "ID of the private route table."
    value       = aws_route_table.private_rt.id
}

output "public_rt_arn" {
    description = "ARN of the public route table."
    value       = aws_route_table.public_rt.arn
}

output "private_rt_arn" {
    description = "ARN of the private route table."
    value       = aws_route_table.private_rt.arn
}

# Internet Gateway Outputs
output "igw_id" {
    description = "The ID of the Internet Gateway."
    value       = aws_internet_gateway.igw.id
}

output "igw_arn" {
    description = "The ARN of the Internet Gateway."
    value       = aws_internet_gateway.igw.arn
}

# NAT Gateway Outputs
output "nat_gateway_id" {
    description = "The ID of the NAT Gateway."
    value       = aws_nat_gateway.nat_gtw.id
}

output "nat_gateway_public_ip" {
    description = "The Elastic IP address of the NAT Gateway."
    value       = aws_eip.nat.public_ip
}