# Bastion Host Outputs
output "bastion_instance_id" {
    description = "The ID of the Bastion host EC2 instance"
    value       = length(var.public_subnet_ids) > 0 ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
    description = "The public IP address of the Bastion host"
    value       = length(var.public_subnet_ids) > 0 ? aws_instance.bastion[0].public_ip : null
}

output "bastion_security_group_id" {
    description = "Security group ID for the Bastion host"
    value       = aws_security_group.bastion_sg.id
}

# Application Server Outputs
output "app_server_instance_id" {
    description = "The ID of the Application server EC2 instance"
    value       = length(var.private_subnet_ids) > 0 ? aws_instance.app_server[0].id : null
}

output "app_server_private_ip" {
    description = "The private IP address of the Application server"
    value       = length(var.private_subnet_ids) > 0 ? aws_instance.app_server[0].private_ip : null
}

output "app_security_group_id" {
    description = "Security group ID for the Application server"
    value       = aws_security_group.app_sg.id
}
