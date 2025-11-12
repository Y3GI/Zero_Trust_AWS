# Base variables

variable "region" {
    description = "Availability zone for services"
    type = string
    default = "eu-north-1a"
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
    default = [ "eu-north-1a" ]
}

# Subnet variables

variable "public_subnets"{
    description = "A list of cidr blocks to use for public subnets"
    type = map(object({
        cidr = string
        az   = string
    }))
    default = {
        public_1 = {
            cidr = "10.0.1.0/24"
            az = "eu-north-1a"
        }
    }
}

variable "private_subnets"{
    description = "A list of cidr blocks to use for public subnets"
    type = map(object({
        cidr = string
        az   = string
    }))
    default = {
        private_1 = {
            cidr = "10.0.2.0/24"
            az = "eu-north-1a"
        }
    }
}

variable "create_isolated_subnet" {
    type = bool
    default = true
}