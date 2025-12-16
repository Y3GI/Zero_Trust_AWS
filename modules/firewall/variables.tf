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
    description = "The VPC ID where the firewall will be deployed"
    type        = string
}

variable "public_subnet_ids" {
    description = "List of public subnet IDs for the firewall deployment"
    type        = list(string)
}