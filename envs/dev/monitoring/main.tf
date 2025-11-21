module "budget" {
    source = "../../../modules/monitoring"
    vpc_id = module.vpc.vpc_id
    flow_log_role_arn = module.security.flow_log_role_arn
}

output "budget_id" {
    value = module.budget.budget_id
}