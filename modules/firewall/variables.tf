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
    description = "The VPC ID from the networking module"
    type        = string
    default = module.vpc.vpc_id
}

variable "subnet_id"{
    description = "A list of subnet IDs within the VPC for deploying the firewall."
    type        = string
    default = module.vpc.public_subnet_ids
}