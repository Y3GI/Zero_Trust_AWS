# Env/Dev Module Linking Reference Guide

## Overview
This document shows how all modules in `envs/dev/` are linked to their corresponding modules in `modules/` directory.

---

## 1. VPC Module (Foundation)

**Location:** `envs/dev/vpc/main.tf`

```terraform
module "vpc" {
    source = "../../../modules/vpc"
    
    env = "dev"
    vpc_cidr = "10.0.0.0/16"
}

# Exposed outputs for other modules
output "vpc_id"                { value = module.vpc.vpc_id }
output "public_subnet_ids"     { value = module.vpc.public_subnet_ids }
output "private_subnet_ids"    { value = module.vpc.private_subnet_ids }
output "isolated_subnet_ids"   { value = module.vpc.isolated_subnet_ids }
output "public_rt_id"          { value = module.vpc.public_rt_id }
output "private_rt_id"         { value = module.vpc.private_rt_id }
```

**Outputs Used By:** security, compute, data_store, firewall, monitoring

---

## 2. Security Module (IAM + KMS)

**Location:** `envs/dev/security/iam.tf`

```terraform
module "iam" {
    source = "../../../modules/security"
}

# Exposed outputs for other modules
output "flow_log_role_arn"         { value = module.iam.flow_log_role_arn }
output "cloudtrail_role_arn"       { value = module.iam.cloudtrail_role_arn }
output "app_instance_role_arn"     { value = module.iam.app_instance_role_arn }
output "app_instance_profile_arn"  { value = module.iam.app_instance_profile_arn }
output "app_instance_profile_name" { value = module.iam.app_instance_profile_name }
output "kms_key_arn"               { value = module.iam.kms_key_arn }
output "kms_key_id"                { value = module.iam.kms_key_id }
```

**Outputs Used By:** compute, data_store, monitoring, secrets (new)

---

## 3. Bootstrap Module (S3 for CloudTrail)

**Location:** `envs/dev/bootstrap/main.tf`

```terraform
module "bootstrap" {
    source = "../../../modules/bootstrap"
    
    env = "dev"
    region = "eu-north-1"
}

# Exposed outputs
output "cloudtrail_bucket_id"   { value = module.bootstrap.cloudtrail_bucket_id }
output "cloudtrail_bucket_name" { value = module.bootstrap.cloudtrail_bucket_name }
```

**Outputs Used By:** vpc_endpoints (new), monitoring

---

## 4. Compute Module (EC2: Bastion + App)

**Location:** `envs/dev/compute/main.tf`

**Linking Pattern (Remote State):**
```terraform
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = { path = "../vpc/terraform.tfstate" }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

module "compute" {
    source = "../../../modules/compute"
    
    # Linked from VPC module
    vpc_id                    = data.terraform_remote_state.vpc.outputs.vpc_id
    public_subnet_ids         = data.terraform_remote_state.vpc.outputs.public_subnet_ids
    private_subnet_ids        = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    
    # Linked from Security module
    app_instance_profile_name = data.terraform_remote_state.security.outputs.app_instance_profile_name
    kms_key_arn              = data.terraform_remote_state.security.outputs.kms_key_arn
    
    # Manual inputs
    bastion_allowed_cidr      = "10.0.1.0/24"
    instance_type             = "t3.micro"
}

# Exposed outputs
output "bastion_instance_id"  { value = module.compute.bastion_instance_id }
output "bastion_public_ip"    { value = module.compute.bastion_public_ip }
output "app_server_instance_id" { value = module.compute.app_server_instance_id }
output "app_server_private_ip"  { value = module.compute.app_server_private_ip }
```

---

## 5. Data Store Module (DynamoDB + VPC Endpoint)

**Location:** `envs/dev/data_store/main.tf`

**Linking Pattern (Remote State):**
```terraform
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = { path = "../vpc/terraform.tfstate" }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

module "data_store" {
    source = "../../../modules/data_store"
    
    # Linked from VPC
    vpc_id          = data.terraform_remote_state.vpc.outputs.vpc_id
    route_table_ids = [
        data.terraform_remote_state.vpc.outputs.private_rt_id,
        data.terraform_remote_state.vpc.outputs.public_rt_id
    ]
    
    # Linked from Security
    kms_key_arn = data.terraform_remote_state.security.outputs.kms_key_arn
}

# Exposed outputs
output "dynamodb_table_name"         { value = module.data_store.dynamodb_table_name }
output "dynamodb_table_arn"          { value = module.data_store.dynamodb_table_arn }
output "dynamodb_vpc_endpoint_id"    { value = module.data_store.dynamodb_vpc_endpoint_id }
```

---

## 6. Firewall Module (AWS Network Firewall)

**Location:** `envs/dev/firewall/main.tf`

**Linking Pattern (Remote State):**
```terraform
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = { path = "../vpc/terraform.tfstate" }
}

module "firewall" {
    source = "../../../modules/firewall"
    
    # Linked from VPC
    vpc_id    = data.terraform_remote_state.vpc.outputs.vpc_id
    subnet_id = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]
}

# Exposed outputs
output "firewall_id"      { value = module.firewall.firewall_id }
output "firewall_arn"     { value = module.firewall.firewall_arn }
output "firewall_policy_id" { value = module.firewall.firewall_policy_id }
output "firewall_status"  { value = module.firewall.firewall_status }
```

---

## 7. Monitoring Module (CloudTrail, VPC Logs, Alarms)

**Location:** `envs/dev/monitoring/main.tf`

**Linking Pattern (Remote State):**
```terraform
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = { path = "../vpc/terraform.tfstate" }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = { path = "../bootstrap/terraform.tfstate" }
}

module "monitoring" {
    source = "../../../modules/monitoring"
    
    # Linked from VPC
    vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
    
    # Linked from Security
    flow_log_role_arn   = data.terraform_remote_state.security.outputs.flow_log_role_arn
    cloudtrail_role_arn = data.terraform_remote_state.security.outputs.cloudtrail_role_arn
    
    # Manual inputs
    email        = "547283@student.fontys.nl"
    limit_amount = 100.00
}

# Exposed outputs
output "budget_id"                    { value = module.monitoring.budget_id }
output "cloudtrail_id"                { value = module.monitoring.cloudtrail_id }
output "flow_logs_id"                 { value = module.monitoring.flow_logs_id }
output "cloudwatch_alarm_id"          { value = module.monitoring.cloudwatch_alarm_id }
output "cloudwatch_log_group_name"    { value = module.monitoring.cloudwatch_log_group_name }
output "cloudtrail_log_group_name"    { value = module.monitoring.cloudtrail_log_group_name }
```

---

## 8. VPC Endpoints Module (NEW) - Private Communication

**Location:** `envs/dev/vpc/main.tf` (to be added)

**How to Add:**
```terraform
# In envs/dev/vpc/main.tf, add after vpc module:

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = { path = "../bootstrap/terraform.tfstate" }
}

module "vpc_endpoints" {
    source = "../../../modules/vpc-endpoints"
    
    # Linked from VPC
    vpc_id                   = module.vpc.vpc_id
    vpc_cidr                 = "10.0.0.0/16"
    private_subnet_ids       = module.vpc.private_subnet_ids
    route_table_ids          = [module.vpc.private_rt_id, module.vpc.public_rt_id]
    
    # Linked from Bootstrap
    cloudtrail_bucket_name   = data.terraform_remote_state.bootstrap.outputs.cloudtrail_bucket_name
}

# Add outputs
output "s3_vpc_endpoint_id"           { value = module.vpc_endpoints.s3_vpc_endpoint_id }
output "secretsmanager_vpc_endpoint_id" { value = module.vpc_endpoints.secretsmanager_vpc_endpoint_id }
output "ssm_vpc_endpoint_id"          { value = module.vpc_endpoints.ssm_vpc_endpoint_id }
```

---

## 9. Secrets Manager Module (NEW) - Credential Storage

**Location:** `envs/dev/security/main.tf` (to be added)

**How to Add:**
```terraform
# In envs/dev/security/main.tf, add after iam module:

module "secrets" {
    source = "../../../modules/secrets"
    
    # Linked from Security module
    kms_key_id   = module.iam.kms_key_id
    app_role_arn = module.iam.app_instance_role_arn
    
    # Sensitive inputs from terraform.tfvars
    db_password = var.db_password
    api_key_1   = var.api_key_1
    api_key_2   = var.api_key_2
    
    # Optional custom values
    db_username = "appuser"
    db_host     = "your-db-host.rds.amazonaws.com"
    db_port     = 5432
    db_name     = "appdb"
}

# Add outputs
output "db_credentials_secret_arn" { value = module.secrets.db_credentials_secret_arn }
output "api_keys_secret_arn"       { value = module.secrets.api_keys_secret_arn }
```

**Create `envs/dev/security/terraform.tfvars`:**
```hcl
db_password = "your-secure-password-here"
api_key_1   = "your-api-key-1"
api_key_2   = "your-api-key-backup"
```

---

## Dependency Graph

```
vpc (foundation)
  ├── security (IAM + KMS)
  ├── bootstrap (S3)
  ├── compute (depends on vpc + security)
  ├── data_store (depends on vpc + security)
  ├── firewall (depends on vpc)
  ├── monitoring (depends on vpc + security + bootstrap)
  ├── vpc_endpoints (depends on vpc + bootstrap) [NEW]
  └── secrets (depends on security) [NEW]
```

---

## Terraform State Management

All modules use **local state** for simplicity in dev environment:

```terraform
# Pattern used across all modules
data "terraform_remote_state" "parent_module" {
    backend = "local"
    config = {
        path = "../parent_module/terraform.tfstate"
    }
}
```

**For Production:** Consider using:
- S3 backend with DynamoDB for locking
- Terraform Cloud/Enterprise
- Proper state isolation per environment

---

## Deployment Order

When deploying, follow this order:

1. `envs/dev/vpc/` - Foundation (VPC, subnets, gateways)
2. `envs/dev/security/` - IAM & KMS
3. `envs/dev/bootstrap/` - S3 for CloudTrail
4. `envs/dev/vpc/` - Add vpc-endpoints module
5. `envs/dev/security/` - Add secrets module
6. `envs/dev/compute/` - EC2 instances
7. `envs/dev/data_store/` - DynamoDB
8. `envs/dev/firewall/` - Network Firewall
9. `envs/dev/monitoring/` - CloudTrail, VPC Logs, Alarms

