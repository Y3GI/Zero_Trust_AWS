module "monitoring"{
    source = "../../../modules/monitoring"
    vpc_id = module.vpc.vpc_id
    flow_log_role_arn = module.security.flow_log_role_arn
    cloudtrail_role_arn = module.security.cloudtrail_role_arn
}