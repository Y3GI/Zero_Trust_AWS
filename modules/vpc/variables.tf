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

# VPC variables

variable "vpc_cidr" {
    description = "The CIDR block for the entire VPC."
    type        = string
    default     = "10.0.0.0/16"
}

# Availability zone

variable "azs" {
    description = "A list of availability zones to use for subnets."
    type        = list(string)
    default = [ "eu-north-1" ]
}

# Subnet variables

variable "public_subnets"{
    description = "A list of cidr blocks to use for public subnets"
    type = map(string)
    default = {
        public_1 = {
            cidr = cidrsubnet(var.vpc_cidr, 3, 1)
            az = "eu-north-1"
        }
    }
}

variable "private_subnets"{
    description = "A list of cidr blocks to use for public subnets"
    type = map(string)
    default = {
        private_1 = {
            cidr = cidrsubnet(var.vpc_cidr, 3, 2)
            az = "eu-north-1"
        }
    }
}

variable "create_isolated_subnet" {
    type = true
}