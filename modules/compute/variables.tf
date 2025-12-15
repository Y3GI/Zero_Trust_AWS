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

variable "vpc_id" {
    description = "The ID of the VPC where compute resources will be deployed."
    type        = string
    default = module.vpc.vpc_id
}

variable "private_subnet_id" {
    description = "A list of subnet IDs within the VPC for deploying compute resources."
    type        = string
    default = module.vpc.private_subnet_ids
}

variable "public_subnet_id" {
    description = "A list of subnet IDs within the VPC for deploying compute resources."
    type        = string
    default = module.vpc.public_subnet_ids
}

variable "bastion_allowed_cidr" {
    description = "The CIDR block that is allowed to access the bastion host."
    type        = string
    default = "10.0.1.100/24"
}

variable "app_instance_profile_name" {
    description = "The name of the IAM instance profile for application instances."
    type        = string
    default = "ztna-app-instance-profile"
}

variable "kms_key_arn" {
    description = "The ARN of the KMS key for encrypting application data."
    type        = string
    default = module.security.kms_key_arn
}

variable "instance_type" {
    description = "The EC2 instance type for application instances."
    type        = string
    default     = "t3.micro"
}