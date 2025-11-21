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

variable "email" {
    type = string
    default = "547283@student.fontys.nl"
}

# Budget monitoring

variable "limit_amount"{
    default = 100.00
}

variable "vpc_id" {
    description = "The VPC ID from the networking module"
    type        = string
    default = module.vpc.vpc_id
}

variable "flow_log_role_arn" {
    description = "The ARN of the IAM role created in the security module"
    type        = string
    default = module.security.flow_log_role_arn
}