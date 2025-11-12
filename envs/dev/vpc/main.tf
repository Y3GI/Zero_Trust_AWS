provider "aws" {
    profile = "default"
    region = "eu-north-1"
}

data "aws_availability_zones" "available"{
    state = "available"
}

module "vpc" {
    source = "../../../modules/vpc"

    env = "dev"
    vpc_cidr = "10.0.0.0/16"
}

output "vpc_id" {
    value = module.vpc.vpc_id
}

output "public_subnet_id"{
    value = module.vpc.public_subnet_ids
}

output "private_subnet_id"{
    value = module.vpc.private_subnet_ids
}

output "isolated_subnet_id"{
    value = module.vpc.isolated_subnet_ids
}