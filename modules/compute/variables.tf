# Base variables

variable "region" {
    description = "Availability zone for services"
    type = string
    default = "eu-north-1"
}

variable "tags"{
    description = "Tags for resources"
    type = map(string)
    default = {
        Environment = "dev"
        Project = "ztna-aws-1"
        Owner = "Boyan Stefanov"
    }
}

variable "env"{
    type = string
    default = "dev"
}

variable "bastion_allowed_cidr" {
    description = "The CIDR block that is allowed to access the bastion host."
    type        = string
    default = "10.0.1.100/24"
}

variable "instance_type" {
    description = "The EC2 instance type for application instances."
    type        = string
    default     = "t3.micro"
}

variable "vpc_id" {
    description = "The VPC ID for compute resources"
    type        = string
}

variable "public_subnet_ids" {
    description = "List of public subnet IDs"
    type        = list(string)
}

variable "private_subnet_ids" {
    description = "List of private subnet IDs"
    type        = list(string)
}

variable "kms_key_arn" {
    description = "ARN of KMS key for encryption"
    type        = string
}

variable "app_instance_profile_name" {
    description = "Name of IAM instance profile for app servers"
    type        = string
}