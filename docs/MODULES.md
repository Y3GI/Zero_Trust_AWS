# Terraform Modules Reference

Detailed reference for all 11 Terraform modules in the Zero Trust AWS infrastructure.

## Module Overview

| Module | Purpose | Outputs |
|--------|---------|---------|
| bootstrap | State management, CloudTrail bucket | Bucket names, ARNs |
| security | IAM roles, KMS keys | Role ARNs, KMS key IDs |
| vpc | Network infrastructure | VPC ID, subnet IDs |
| compute | EC2 instances | Instance IDs, IPs |
| data_store | DynamoDB tables | Table names, ARNs |
| firewall | AWS Network Firewall | Firewall ID, policy ID |
| monitoring | CloudTrail, CloudWatch | Trail ID, log group names |
| secrets | Secrets Manager | Secret ARNs |
| certificates | ACM Private CA | CA ARN |
| rbac-authorization | IAM policies | Policy ARNs |
| vpc-endpoints | VPC endpoints | Endpoint IDs |

---

## bootstrap

Creates foundational S3 buckets for Terraform state and CloudTrail logs.

### Resources Created

- `aws_s3_bucket` - Terraform state bucket
- `aws_s3_bucket` - CloudTrail logs bucket
- `aws_s3_bucket_versioning` - Enable versioning
- `aws_s3_bucket_server_side_encryption_configuration` - Encryption
- `aws_s3_bucket_public_access_block` - Block public access

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | `"dev"` | Environment name |
| `region` | string | `"eu-north-1"` | AWS region |
| `kms_key_id` | string | `""` | Optional KMS key for encryption |

### Outputs

| Name | Description |
|------|-------------|
| `terraform_state_bucket_id` | State bucket ID |
| `terraform_state_bucket_name` | State bucket name |
| `cloudtrail_bucket_id` | CloudTrail bucket ID |
| `cloudtrail_bucket_name` | CloudTrail bucket name |

### Usage

```hcl
module "bootstrap" {
  source = "../../modules/bootstrap"
  
  env        = "dev"
  region     = "eu-north-1"
  kms_key_id = ""  # Use AES256 if empty
}
```

---

## security

Creates IAM roles, KMS keys, and instance profiles for secure access.

### Resources Created

- `aws_iam_role` - App instance role
- `aws_iam_role` - VPC Flow Logs role
- `aws_iam_role` - CloudTrail role
- `aws_iam_instance_profile` - EC2 instance profile
- `aws_kms_key` - Customer-managed encryption key
- `aws_kms_alias` - Key alias

### Outputs

| Name | Description |
|------|-------------|
| `app_instance_role_arn` | App role ARN |
| `app_instance_role_name` | App role name |
| `app_instance_profile_arn` | Instance profile ARN |
| `app_instance_profile_name` | Instance profile name |
| `flow_log_role_arn` | Flow Logs role ARN |
| `cloudtrail_role_arn` | CloudTrail role ARN |
| `kms_key_arn` | KMS key ARN |
| `kms_key_id` | KMS key ID |
| `kms_key_alias` | KMS key alias |

### Usage

```hcl
module "security" {
  source = "../../modules/security"
}
```

---

## vpc

Creates VPC, subnets, gateways, and route tables.

### Resources Created

- `aws_vpc` - Main VPC
- `aws_subnet` - Public, private, isolated subnets
- `aws_internet_gateway` - Internet access
- `aws_nat_gateway` - Outbound for private subnets
- `aws_route_table` - Public and private routes
- `aws_eip` - Elastic IP for NAT

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | `"dev"` | Environment name |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR block |
| `public_subnets` | map | See defaults | Public subnet config |
| `private_subnets` | map | See defaults | Private subnet config |
| `create_isolated_subnet` | bool | `true` | Create isolated subnet |

### Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_arn` | VPC ARN |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `isolated_subnet_ids` | List of isolated subnet IDs |
| `public_rt_id` | Public route table ID |
| `private_rt_id` | Private route table ID |
| `igw_id` | Internet Gateway ID |
| `nat_gateway_id` | NAT Gateway ID |

### Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  env      = "dev"
  vpc_cidr = "10.0.0.0/16"
}
```

---

## compute

Creates EC2 instances for bastion and application servers.

### Resources Created

- `aws_instance` - Bastion host (public subnet)
- `aws_instance` - App server (private subnet)
- `aws_security_group` - Bastion security group
- `aws_security_group` - App security group

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `vpc_id` | string | required | VPC ID |
| `public_subnet_ids` | list | required | Public subnet IDs |
| `private_subnet_ids` | list | required | Private subnet IDs |
| `instance_type` | string | `"t3.micro"` | EC2 instance type |
| `bastion_allowed_cidr` | string | required | Allowed CIDR for bastion |
| `kms_key_arn` | string | required | KMS key for EBS |
| `app_instance_profile_name` | string | required | IAM instance profile |

### Outputs

| Name | Description |
|------|-------------|
| `bastion_instance_id` | Bastion instance ID |
| `bastion_public_ip` | Bastion public IP |
| `bastion_security_group_id` | Bastion SG ID |
| `app_server_instance_id` | App server instance ID |
| `app_server_private_ip` | App server private IP |

### Usage

```hcl
module "compute" {
  source = "../../modules/compute"
  
  env                       = "dev"
  region                    = "eu-north-1"
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  instance_type             = "t3.micro"
  bastion_allowed_cidr      = "10.0.1.0/24"
  kms_key_arn               = module.security.kms_key_arn
  app_instance_profile_name = module.security.app_instance_profile_name
}
```

---

## data_store

Creates DynamoDB tables for Terraform state locking and application data.

### Resources Created

- `aws_dynamodb_table` - Terraform locks table
- `aws_dynamodb_table` - Application data table

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `kms_key_arn` | string | required | KMS key for encryption |

### Outputs

| Name | Description |
|------|-------------|
| `terraform_locks_table_name` | Locks table name |
| `terraform_locks_table_arn` | Locks table ARN |
| `dynamodb_table_name` | App table name |
| `dynamodb_table_arn` | App table ARN |

---

## firewall

Creates AWS Network Firewall for traffic inspection.

### Resources Created

- `aws_networkfirewall_firewall` - Network Firewall
- `aws_networkfirewall_firewall_policy` - Firewall policy
- `aws_networkfirewall_rule_group` - Stateful rules

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `vpc_id` | string | required | VPC ID |
| `public_subnet_ids` | list | required | Subnet IDs for firewall |

### Outputs

| Name | Description |
|------|-------------|
| `firewall_id` | Firewall ID |
| `firewall_arn` | Firewall ARN |
| `firewall_policy_id` | Policy ID |
| `firewall_status` | Firewall status |

---

## monitoring

Creates CloudTrail, CloudWatch, and budget monitoring.

### Resources Created

- `aws_cloudtrail` - API audit trail
- `aws_cloudwatch_log_group` - Log groups
- `aws_cloudwatch_metric_alarm` - Alarms
- `aws_budgets_budget` - Cost budget
- `aws_flow_log` - VPC Flow Logs

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `vpc_id` | string | required | VPC ID for flow logs |
| `flow_log_role_arn` | string | required | IAM role for flow logs |
| `cloudtrail_role_arn` | string | required | IAM role for CloudTrail |
| `cloudtrail_bucket_name` | string | required | S3 bucket for logs |
| `email` | string | required | Alert email address |
| `limit_amount` | number | `100` | Budget limit in USD |

### Outputs

| Name | Description |
|------|-------------|
| `budget_id` | Budget ID |
| `cloudtrail_id` | CloudTrail ID |
| `flow_logs_id` | VPC Flow Logs ID |
| `cloudwatch_alarm_id` | Alarm ID |
| `cloudwatch_log_group_name` | Log group name |

---

## secrets

Creates Secrets Manager secrets for credentials.

### Resources Created

- `aws_secretsmanager_secret` - DB credentials secret
- `aws_secretsmanager_secret` - API keys secret
- `aws_secretsmanager_secret_version` - Secret values

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `kms_key_id` | string | required | KMS key for encryption |
| `app_instance_role_arn` | string | required | Role allowed to access |
| `db_username` | string | required | Database username |
| `db_password` | string | required | Database password (sensitive) |
| `db_host` | string | required | Database host |
| `db_port` | number | `5432` | Database port |
| `db_name` | string | required | Database name |
| `api_key_1` | string | required | API key 1 (sensitive) |
| `api_key_2` | string | required | API key 2 (sensitive) |

### Outputs

| Name | Description |
|------|-------------|
| `db_credentials_secret_arn` | DB secret ARN |
| `api_keys_secret_arn` | API keys secret ARN |

---

## certificates

Creates ACM Private Certificate Authority for mTLS.

### Resources Created

- `aws_acmpca_certificate_authority` - Private CA

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |

### Outputs

| Name | Description |
|------|-------------|
| `root_ca_arn` | Root CA ARN |

---

## rbac-authorization

Creates IAM policies for role-based access control.

### Resources Created

- `aws_iam_policy` - Bastion access policy
- `aws_iam_policy` - App server policy

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |

### Outputs

| Name | Description |
|------|-------------|
| `bastion_policy_arn` | Bastion policy ARN |
| `app_server_policy_arn` | App policy ARN |

---

## vpc-endpoints

Creates VPC endpoints for private AWS service access.

### Resources Created

- `aws_vpc_endpoint` - S3 Gateway endpoint
- `aws_vpc_endpoint` - DynamoDB Gateway endpoint
- `aws_vpc_endpoint` - Secrets Manager Interface endpoint
- `aws_vpc_endpoint` - SSM Interface endpoint
- `aws_vpc_endpoint` - SSM Messages Interface endpoint
- `aws_vpc_endpoint` - EC2 Messages Interface endpoint
- `aws_vpc_endpoint` - CloudWatch Logs Interface endpoint
- `aws_vpc_endpoint` - KMS Interface endpoint
- `aws_security_group` - Endpoint security group

### Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `env` | string | required | Environment name |
| `region` | string | required | AWS region |
| `vpc_id` | string | required | VPC ID |
| `vpc_cidr` | string | required | VPC CIDR |
| `private_rt_id` | string | required | Private route table ID |
| `public_rt_id` | string | required | Public route table ID |
| `private_subnet_ids` | list | required | Private subnet IDs |
| `cloudtrail_bucket_name` | string | required | CloudTrail bucket name |

### Outputs

| Name | Description |
|------|-------------|
| `s3_vpc_endpoint_id` | S3 endpoint ID |
| `dynamodb_vpc_endpoint_id` | DynamoDB endpoint ID |
| `secretsmanager_vpc_endpoint_id` | Secrets Manager endpoint ID |
| `ssm_vpc_endpoint_id` | SSM endpoint ID |
