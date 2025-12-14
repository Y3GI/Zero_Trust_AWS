module "monitoring"{
    source = "../../../modules/monitoring"
    vpc_id = module.vpc.vpc_id
    flow_log_role_arn = module.security.flow_log_role_arn
    cloudtrail_role_arn = module.security.cloudtrail_role_arn
}

output "monitoring_cloudtrail_id" {
    value = module.monitoring.cloudtrail_id
}

output "monitoring_flow_log_id" {
    value = module.monitoring.flow_log_id
}

output "monitoring_cloudwatch_alarm_id" {
    value = module.monitoring.cloudwatch_alarm_id
}