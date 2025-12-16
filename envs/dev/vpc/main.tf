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

output "vpc_arn" {
    value = module.vpc.vpc_arn
}

output "vpc_cidr" {
    value = module.vpc.vpc_cidr
}

output "public_subnet_id"{
    value = module.vpc.public_subnet_ids
}

output "public_subnet_ids"{
    value = module.vpc.public_subnet_ids
}

output "private_subnet_id"{
    value = module.vpc.private_subnet_ids
}

output "private_subnet_ids"{
    value = module.vpc.private_subnet_ids
}

output "isolated_subnet_id"{
    value = module.vpc.isolated_subnet_ids
}

output "isolated_subnet_ids"{
    value = module.vpc.isolated_subnet_ids
}

output "public_rt_id" {
    value = module.vpc.public_rt_id
}

output "private_rt_id" {
    value = module.vpc.private_rt_id
}

output "public_rt_arn" {
    value = module.vpc.public_rt_arn
}

output "private_rt_arn" {
    value = module.vpc.private_rt_arn
}

output "igw_id" {
    value = module.vpc.igw_id
}

output "igw_arn" {
    value = module.vpc.igw_arn
}

output "nat_gateway_id" {
    value = module.vpc.nat_gateway_id
}

output "nat_gateway_public_ip" {
    value = module.vpc.nat_gateway_public_ip
}