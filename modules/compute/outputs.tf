# Bastion Host Outputs
output "bastion_instance_id" {
    description = "The ID of the Bastion host EC2 instance"
    value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
    description = "The public IP address of the Bastion host"
    value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
    description = "Security group ID for the Bastion host"
    value       = aws_security_group.bastion_sg.id
}

# Application Server Outputs
output "app_server_instance_id" {
    description = "The ID of the Application server EC2 instance"
    value       = aws_instance.app_server.id
}

output "app_server_private_ip" {
    description = "The private IP address of the Application server"
    value       = aws_instance.app_server.private_ip
}

output "app_security_group_id" {
    description = "Security group ID for the Application server"
    value       = aws_security_group.app_sg.id
}
