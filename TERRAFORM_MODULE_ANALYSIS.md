# Zero Trust AWS - Terraform Module Analysis

## Overview
This document provides a comprehensive analysis of all Terraform modules in the Zero Trust AWS infrastructure, including variables, outputs, and key resource identifiers. This information is essential for fixing integration tests to match actual infrastructure configuration.

---

## 1. BOOTSTRAP Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/bootstrap`

### Purpose
Creates foundational AWS infrastructure components:
- S3 bucket for Terraform state storage with versioning and KMS encryption
- S3 bucket for CloudTrail audit logs
- CloudTrail bucket policy for audit logging

### Required Variables
None - all variables have defaults

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | Availability zone for services |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |
| `kms_key_id` | string | `""` | KMS key ID for encrypting Terraform state S3 bucket |

### Outputs
| Name | Description |
|------|-------------|
| `terraform_state_bucket_id` | The ID of the S3 bucket for Terraform state |
| `terraform_state_bucket_name` | The name of the S3 bucket for Terraform state |
| `terraform_state_bucket_arn` | The ARN of the S3 bucket for Terraform state |
| `cloudtrail_bucket_id` | The ID of the S3 bucket for CloudTrail logs |
| `cloudtrail_bucket_arn` | The ARN of the S3 bucket for CloudTrail logs |
| `cloudtrail_bucket_name` | The name of the S3 bucket for CloudTrail logs |
| `cloudtrail_bucket_policy_id` | The ID of the CloudTrail bucket policy |

### Key Resources
- `aws_s3_bucket.terraform_state` - State bucket: `${env}-terraform-state-${account_id}`
- `aws_s3_bucket.cloudtrail_bucket` - CloudTrail bucket: `${env}-ztna-audit-logs-${random_suffix}`
- `aws_s3_bucket_versioning.terraform_state` - State bucket versioning enabled
- `aws_s3_bucket_server_side_encryption_configuration.terraform_state` - KMS encryption
- `aws_s3_bucket_policy.cloudtrail_bucket_policy` - CloudTrail write permissions

---

## 2. VPC Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/vpc`

### Purpose
Creates the main VPC infrastructure including:
- VPC with public, private, and isolated subnets
- Internet Gateway and NAT Gateway
- Public and private route tables

### Required Variables
None - all variables have defaults

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1a"` | Availability zone for services |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |
| `vpc_cidr` | string | `"10.0.0.0/16"` | CIDR block for entire VPC |
| `azs` | list(string) | `["eu-north-1a"]` | List of availability zones for subnets |
| `public_subnets` | map(object) | `{public_1={cidr="10.0.1.0/24", az="eu-north-1a"}}` | Public subnet configuration |
| `private_subnets` | map(object) | `{private_1={cidr="10.0.2.0/24", az="eu-north-1a"}}` | Private subnet configuration |
| `create_isolated_subnet` | bool | `true` | Whether to create isolated subnets |

### Outputs
| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the main application VPC |
| `vpc_arn` | The ARN of the main application VPC |
| `vpc_cidr` | The CIDR block of the main application VPC |
| `public_subnet_ids` | List of IDs for public subnets (IGW access) |
| `private_subnet_ids` | List of IDs for private subnets (Application tier) |
| `isolated_subnet_ids` | List of IDs for restricted subnets (Database tier) |
| `public_rt_id` | ID of the public route table |
| `private_rt_id` | ID of the private route table |
| `public_rt_arn` | ARN of the public route table |
| `private_rt_arn` | ARN of the private route table |
| `igw_id` | The ID of the Internet Gateway |
| `igw_arn` | The ARN of the Internet Gateway |
| `nat_gateway_id` | The ID of the NAT Gateway |
| `nat_gateway_public_ip` | The Elastic IP address of the NAT Gateway |

### Key Resources
- `aws_vpc.main` - VPC: `10.0.0.0/16` with DNS support enabled
- `aws_subnet.public[*]` - Public subnets (default: `10.0.1.0/24`)
- `aws_subnet.private[*]` - Private subnets (default: `10.0.2.0/24`)
- `aws_subnet.isolated[*]` - Isolated subnets for database tier
- `aws_internet_gateway.igw` - Internet gateway: `${env}-igw`
- `aws_nat_gateway.nat_gtw` - NAT gateway: `${env}-nat-gtw`
- `aws_eip.nat` - Elastic IP for NAT: `${env}-nat`
- `aws_route_table.public_rt` - Public route table
- `aws_route_table.private_rt` - Private route table

---

## 3. SECURITY Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/security`

### Purpose
Creates security foundations:
- KMS encryption key with key policy
- IAM roles for application instances, VPC Flow Logs, and CloudTrail
- Instance profiles for EC2 attachment

### Required Variables
None - all variables have defaults

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `app_instance_role_arn` | ARN of the IAM role for application instances |
| `app_instance_role_name` | Name of the IAM role for application instances |
| `app_instance_profile_arn` | ARN of the Instance Profile to attach to EC2 resources |
| `app_instance_profile_name` | Name of the Instance Profile to attach to EC2 resources |
| `flow_log_role_arn` | ARN of the IAM role for VPC Flow Logs |
| `flow_log_role_name` | Name of the IAM role for VPC Flow Logs |
| `cloudtrail_role_arn` | ARN of the IAM role for CloudTrail |
| `cloudtrail_role_name` | Name of the IAM role for CloudTrail |
| `kms_key_arn` | ARN of the KMS key used for encrypting resources |
| `kms_key_id` | The ID of the KMS key |
| `kms_key_alias` | The alias of the KMS key: `alias/${env}-ztna-key` |
| `kms_key_policy_id` | The ID of the KMS key policy |

### Key Resources
- `aws_kms_key.main` - KMS encryption key: `${env}-ztna-key` with 30-day deletion window
- `aws_kms_alias.main` - KMS alias: `alias/${env}-ztna-key`
- `aws_iam_role.app_instance_role` - App instance IAM role: `${env}-app-instance-role`
- `aws_iam_instance_profile.app_instance_profile` - Instance profile for EC2
- `aws_iam_role.vpc_flow_log_role` - VPC Flow Logs IAM role
- `aws_iam_role.cloudtrail_role` - CloudTrail IAM role
- `aws_kms_key_policy.main` - KMS key policy with root and app role permissions

---

## 4. COMPUTE Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/compute`

### Purpose
Deploys EC2 infrastructure:
- Bastion host in public subnet
- Application server in private subnet
- Security groups with microsegmentation rules

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `vpc_id` | string | The VPC ID for compute resources |
| `public_subnet_ids` | list(string) | List of public subnet IDs |
| `private_subnet_ids` | list(string) | List of private subnet IDs |
| `kms_key_arn` | string | ARN of KMS key for encryption |
| `app_instance_profile_name` | string | Name of IAM instance profile for app servers |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |
| `bastion_allowed_cidr` | string | `"10.0.1.100/24"` | CIDR block allowed for bastion SSH |
| `instance_type` | string | `"t3.micro"` | EC2 instance type |

### Outputs
| Name | Description |
|------|-------------|
| `bastion_instance_id` | The ID of the Bastion host EC2 instance |
| `bastion_public_ip` | The public IP address of the Bastion host |
| `bastion_security_group_id` | Security group ID for the Bastion host |
| `app_server_instance_id` | The ID of the Application server EC2 instance |
| `app_server_private_ip` | The private IP address of the Application server |
| `app_security_group_id` | Security group ID for the Application server |

### Key Resources
- `aws_instance.bastion` - Bastion EC2 instance (conditional): `${env}-Bastion-Host`
  - Uses latest Amazon Linux 2023 AMI
  - Instance type: `t3.micro`
  - Public IP association enabled
  - KMS-encrypted root volume
- `aws_security_group.bastion_sg` - Bastion security group: `${env}-bastion-sg`
  - Allows SSH (port 22) from `10.0.1.100/24`
  - All outbound traffic allowed
- `aws_instance.app_server` - Application EC2 instance (conditional): `${env}-app-server`
  - Uses latest Amazon Linux 2023 AMI
  - Instance type: `t3.micro` (configurable)
  - Private IP only
  - KMS-encrypted root volume
- `aws_security_group.app_sg` - App security group: `${env}-app-sg`
  - Allows SSH only from Bastion security group
  - All outbound traffic allowed

---

## 5. DATA_STORE Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/data_store`

### Purpose
Creates database infrastructure:
- DynamoDB tables for application data and Terraform state locking
- Server-side encryption with KMS
- Point-in-time recovery enabled

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `kms_key_arn` | string | ARN of KMS key for DynamoDB encryption |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `terraform_locks_table_name` | The name of the DynamoDB table for Terraform state locking |
| `terraform_locks_table_arn` | The ARN of the DynamoDB table for Terraform state locking |
| `dynamodb_table_name` | The name of the DynamoDB table |
| `dynamodb_table_arn` | The ARN of the DynamoDB table |
| `dynamodb_table_id` | The ID of the DynamoDB table |

### Key Resources
- `aws_dynamodb_table.terraform_locks` - Terraform locks table: `${env}-terraform-locks`
  - Hash key: `LockID` (String)
  - Billing: `PAY_PER_REQUEST`
  - KMS encryption enabled
- `aws_dynamodb_table.main` - Application data table: `${env}-ztna-table`
  - Hash key: `LockID` (String)
  - Billing: `PAY_PER_REQUEST`
  - KMS encryption enabled
  - Point-in-time recovery enabled

---

## 6. FIREWALL Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/firewall`

### Purpose
Deploys AWS Network Firewall:
- Network Firewall rule groups (HTTPS allow, HTTP drop)
- Firewall policy
- Firewall appliance in public subnets

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `vpc_id` | string | The VPC ID where firewall will be deployed |
| `public_subnet_ids` | list(string) | List of public subnet IDs for firewall |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `firewall_rule_group_id` | The ID of the Network Firewall rule group |
| `firewall_rule_group_arn` | The ARN of the Network Firewall rule group |
| `firewall_policy_id` | The ID of the Network Firewall policy |
| `firewall_policy_arn` | The ARN of the Network Firewall policy |
| `firewall_id` | The ID of the Network Firewall |
| `firewall_arn` | The ARN of the Network Firewall |
| `firewall_status` | The operational status of the Network Firewall |

### Key Resources
- `aws_networkfirewall_rule_group.allow_web` - Rule group: `${env}-web-allow-rules`
  - Capacity: 100
  - Type: STATEFUL
  - Rules: Allow HTTPS (port 443), Drop HTTP (port 80)
- `aws_networkfirewall_firewall_policy.main` - Policy: `${env}-firewall-policy`
  - Stateless default actions: Forward to SFE
  - References stateful rule group
- `aws_networkfirewall_firewall.main` - Firewall: `${env}-network-firewall`
  - Deployed in all public subnets
  - Subnet change protection disabled

---

## 7. MONITORING Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/monitoring`

### Purpose
Implements monitoring and auditing:
- VPC Flow Logs with CloudWatch integration
- CloudTrail for audit logging
- CloudWatch alarms for network activity
- AWS Budgets for cost monitoring

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `vpc_id` | string | VPC ID for CloudWatch Flow Logs |
| `flow_log_role_arn` | string | ARN of IAM role for VPC Flow Logs |
| `cloudtrail_role_arn` | string | ARN of IAM role for CloudTrail |
| `cloudtrail_bucket_name` | string | Name of S3 bucket for CloudTrail logs |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |
| `email` | string | `"547283@student.fontys.nl"` | Email for budget notifications |
| `limit_amount` | number | `100.00` | Monthly budget limit in USD |

### Outputs
| Name | Description |
|------|-------------|
| `budget_id` | The ID of the AWS Budget |
| `cloudwatch_log_group_id` | The ID of the CloudWatch log group for VPC Flow Logs |
| `cloudwatch_log_group_name` | The name of the CloudWatch log group for VPC Flow Logs |
| `cloudwatch_log_group_arn` | The ARN of the CloudWatch log group for VPC Flow Logs |
| `cloudtrail_log_group_id` | The ID of the CloudWatch log group for CloudTrail |
| `cloudtrail_log_group_name` | The name of the CloudWatch log group for CloudTrail |
| `cloudtrail_log_group_arn` | The ARN of the CloudWatch log group for CloudTrail |
| `flow_logs_id` | The ID of the VPC Flow Logs configuration |
| `flow_logs_arn` | The ARN of the VPC Flow Logs configuration |
| `cloudwatch_alarm_id` | The ID of the VPC rejects alarm |
| `cloudwatch_alarm_arn` | The ARN of the VPC rejects alarm |
| `cloudtrail_id` | The ID of the CloudTrail |
| `cloudtrail_arn` | The ARN of the CloudTrail |

### Key Resources
- `aws_flow_log.main` - VPC Flow Logs configuration
  - Destination: CloudWatch Logs
  - Log group: `/aws/vpc/flowlogs/${env}`
  - Traffic type: ACCEPT and REJECT
- `aws_cloudwatch_log_group.vpc_flow_logs` - Flow Logs CloudWatch group
  - Retention: 30 days
- `aws_cloudwatch_log_group.cloudtrail_events` - CloudTrail CloudWatch group
  - Log group: `/aws/cloudtrail/${env}`
  - Retention: 90 days
- `aws_cloudtrail.main` - CloudTrail: `${env}-audit-trail`
  - Multi-region trail: Enabled
  - Global service events: Included
  - Log file validation: Enabled
  - S3 bucket: CloudTrail bucket
  - CloudWatch Logs integration: Enabled
- `aws_cloudwatch_metric_alarm.high_rejects` - Alarm for packet rejections
  - Threshold: High rejects from Flow Logs
- `aws_budgets_budget.monthly` - Monthly cost budget
  - Limit: $100.00 USD
  - Notification email: `547283@student.fontys.nl`

---

## 8. CERTIFICATES Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/certificates`

### Purpose
Creates certificate authority infrastructure:
- AWS ACM Private CA for internal PKI
- Root CA for ZTNA certificate issuance

### Required Variables
None - all variables have defaults

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `root_ca_arn` | ARN of the root Certificate Authority |
| `root_ca_domain` | Domain of the root CA |

### Key Resources
- `aws_acmpca_certificate_authority.ca` - Root CA: `ca.ztna.local`
  - Key algorithm: RSA_2048
  - Signing algorithm: SHA256WITHRSA
  - Common name: `ca.ztna.local`
  - Deletion window: 7 days (AWS minimum)
  - Status: INACTIVE (must be activated before use)

---

## 9. RBAC-AUTHORIZATION Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/rbac-authorization`

### Purpose
Implements role-based access control (RBAC) policies:
- Bastion host restricted access policy
- Application server restricted access policy
- Database restricted access policy
- Enforce tagging policy for compliance

### Required Variables
None - all variables have defaults

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `bastion_policy_arn` | ARN of the bastion restricted access policy |
| `app_server_policy_arn` | ARN of the app server restricted access policy |
| `database_policy_arn` | ARN of the database restricted access policy |
| `enforce_tagging_policy_arn` | ARN of the enforce tagging policy |

### Key Resources
- `aws_iam_policy.bastion_restricted_access` - Bastion policy: `${env}-bastion-restricted-access`
  - Conditions: Assumes roles tagged with Environment=${env}, Tier=bastion
  - Allows: AssumeRole, SessionManager
  - Denies: Internet gateway/NAT gateway creation
- `aws_iam_policy.app_server_restricted_access` - App server policy: `${env}-app-server-restricted-access`
  - Conditions: Environment=${env}, Tier=application
  - Allows: Secrets Manager access, KMS decrypt, DynamoDB access
  - Service conditions: secretsmanager, kms, dynamodb
- `aws_iam_policy.database_restricted_access` - Database policy: `${env}-database-restricted-access`
  - Conditions: Environment=${env}, Tier=database
  - Allows: DynamoDB access, KMS decrypt
  - Denies: Data deletion operations
- `aws_iam_policy.enforce_tagging` - Enforce tagging policy
  - Requires Environment, Project, Owner tags
  - Blocks untagged resource creation

---

## 10. SECRETS Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/secrets`

### Purpose
Manages sensitive data storage:
- AWS Secrets Manager secrets for database credentials
- AWS Secrets Manager secrets for API keys
- KMS encryption for secrets
- Secret recovery mechanism for deleted secrets

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `kms_key_id` | string | ID of KMS key for Secrets Manager encryption |
| `app_instance_role_arn` | string | ARN of IAM role for app instances |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |
| `db_username` | string | `"admin"` | Database username (sensitive) |
| `db_password` | string | `"P@ssw0rd!"` | Database password (sensitive) |
| `db_host` | string | `"localhost"` | Database host |
| `db_port` | number | `5432` | Database port |
| `db_name` | string | `"ztna_db"` | Database name |
| `api_key_1` | string | `"default_api_key_1_value"` | First API key (sensitive) |
| `api_key_2` | string | `"default_api_key_2_value"` | Second API key backup (sensitive) |

### Outputs
| Name | Description |
|------|-------------|
| `db_credentials_secret_arn` | ARN of the database credentials secret |
| `db_credentials_secret_name` | Name of the database credentials secret |
| `api_keys_secret_arn` | ARN of the API keys secret |
| `api_keys_secret_name` | Name of the API keys secret |
| `secrets_rotation_enabled` | Whether automatic rotation is enabled (30 days) |

### Key Resources
- `aws_secretsmanager_secret.db_credentials` - DB credentials secret: `${env}/app/db-credentials`
  - KMS encryption enabled
  - Recovery window: 0 days (immediate deletion)
  - Secret value: JSON with username, password, host, port, database
- `aws_secretsmanager_secret_version.db_credentials` - DB credentials version
  - Contains: username, password, host, port, database
- `aws_secretsmanager_secret.api_keys` - API keys secret: `${env}/app/api-keys`
  - KMS encryption enabled
  - Recovery window: 0 days (immediate deletion)
  - Secret value: JSON with api_key_v1, api_key_v2
- `aws_secretsmanager_secret_version.api_keys` - API keys version
  - Contains: api_key_v1, api_key_v2
- `terraform_data.recover_secrets` - Recovery provisioner for deleted secrets

---

## 11. VPC-ENDPOINTS Module
**Path:** `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/modules/vpc-endpoints`

### Purpose
Deploys VPC endpoints for private AWS service access:
- Gateway endpoints for S3 and DynamoDB
- Interface endpoints for Secrets Manager, Systems Manager, EC2, CloudWatch, KMS, STS
- Security group for interface endpoints
- S3 endpoint policy restricting CloudTrail access

### Required Variables
| Name | Type | Description |
|------|------|-------------|
| `vpc_id` | string | VPC ID for VPC endpoints |
| `private_rt_id` | string | ID of private route table |
| `public_rt_id` | string | ID of public route table |
| `private_subnet_ids` | list(string) | IDs of private subnets |
| `cloudtrail_bucket_name` | string | Name of S3 bucket for CloudTrail logs |

### Optional Variables
| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `"eu-north-1"` | AWS region |
| `env` | string | `"dev"` | Environment name |
| `vpc_cidr` | string | `"10.0.0.0/16"` | CIDR block of the VPC |
| `tags` | map(string) | `{Environment="dev", Project="ztna-aws-1", Owner="Boyan Stefanov"}` | Tags for resources |

### Outputs
| Name | Description |
|------|-------------|
| `s3_vpc_endpoint_id` | The ID of the S3 VPC Endpoint |
| `secretsmanager_vpc_endpoint_id` | The ID of the Secrets Manager VPC Endpoint |
| `secretsmanager_vpc_endpoint_dns` | The DNS name of the Secrets Manager VPC Endpoint |
| `ssm_vpc_endpoint_id` | The ID of the Systems Manager VPC Endpoint |
| `ec2messages_vpc_endpoint_id` | The ID of the EC2 Messages VPC Endpoint |
| `ssmmessages_vpc_endpoint_id` | The ID of the SSM Messages VPC Endpoint |
| `sts_vpc_endpoint_id` | The ID of the STS VPC Endpoint |
| `logs_vpc_endpoint_id` | The ID of the CloudWatch Logs VPC Endpoint |
| `kms_vpc_endpoint_id` | The ID of the KMS VPC Endpoint |
| `vpc_endpoints_security_group_id` | The ID of the security group for VPC endpoints |
| `dynamodb_vpc_endpoint_id` | The ID of the DynamoDB VPC endpoint |
| `dynamodb_vpc_endpoint_arn` | The ARN of the DynamoDB VPC endpoint |

### Key Resources
- `aws_vpc_endpoint.s3` - S3 Gateway endpoint: `${env}-s3-endpoint`
  - Route table associations: Public and Private
  - Policy: Allow all S3 actions on CloudTrail bucket
- `aws_vpc_endpoint.dynamodb` - DynamoDB Gateway endpoint: `${env}-dynamodb-endpoint`
  - Route table associations: Public and Private
- `aws_vpc_endpoint.secretsmanager` - Secrets Manager Interface endpoint: `${env}-secretsmanager-endpoint`
  - Subnets: All private subnets
  - Private DNS enabled
  - Security group: VPC endpoints security group
- `aws_vpc_endpoint.ssm` - Systems Manager Interface endpoint: `${env}-ssm-endpoint`
  - Subnets: All private subnets
  - Private DNS enabled
  - Service: `com.amazonaws.${region}.ssm`
- `aws_vpc_endpoint.ec2messages` - EC2 Messages Interface endpoint: `${env}-ec2messages-endpoint`
  - Service: `com.amazonaws.${region}.ec2messages`
- `aws_vpc_endpoint.ssmmessages` - SSM Messages Interface endpoint: `${env}-ssmmessages-endpoint`
  - Service: `com.amazonaws.${region}.ssmmessages`
- `aws_vpc_endpoint.sts` - STS Interface endpoint: `${env}-sts-endpoint`
  - Service: `com.amazonaws.${region}.sts`
- `aws_vpc_endpoint.logs` - CloudWatch Logs Interface endpoint: `${env}-logs-endpoint`
  - Service: `com.amazonaws.${region}.logs`
- `aws_vpc_endpoint.kms` - KMS Interface endpoint: `${env}-kms-endpoint`
  - Service: `com.amazonaws.${region}.kms`
- `aws_security_group.vpc_endpoints` - VPC endpoints security group: `${env}-vpc-endpoints-sg`
  - Allows HTTPS (port 443) from VPC CIDR
  - All outbound traffic allowed

---

## Deployment Dependency Graph

```
bootstrap (foundation)
    ↓
security (KMS key, IAM roles)
    ↓
vpc (VPC, subnets, gateways)
    ↓
├── compute (EC2 instances) → requires vpc + security
├── firewall (Network Firewall) → requires vpc
├── data_store (DynamoDB) → requires security (KMS key)
├── monitoring (CloudWatch, CloudTrail) → requires bootstrap + security
├── vpc-endpoints (VPC endpoints) → requires vpc + bootstrap
├── certificates (ACM PCA) → standalone
├── rbac-authorization (IAM policies) → standalone
└── secrets (Secrets Manager) → requires security
```

---

## Common Patterns

### Resource Naming Convention
- S3 buckets: `${env}-${purpose}-${random_suffix}`
- EC2 instances: `${env}-${role}`
- IAM roles: `${env}-${purpose}-role`
- KMS keys: `${env}-${purpose}-key` with alias `alias/${env}-${purpose}-key`
- DynamoDB tables: `${env}-${purpose}-table` or `${env}-${purpose}`
- Security groups: `${env}-${purpose}-sg`
- VPC Endpoints: `${env}-${service}-endpoint`
- CloudWatch log groups: `/aws/${service}/${env}` or similar

### Tags Applied to All Resources
```
Environment = "dev"
Project     = "ztna-aws-1"
Owner       = "Boyan Stefanov"
```

### Encryption
- All data at rest encrypted with KMS key from security module
- S3 buckets: Server-side encryption with KMS
- DynamoDB tables: Server-side encryption with KMS
- Secrets Manager: Encryption with KMS key
- EC2 volumes: Encrypted root block devices with KMS

### Network Security
- Public subnets: Internet Gateway access (NAT for private egress)
- Private subnets: NAT Gateway for outbound, isolated from internet
- Isolated subnets: No internet access
- Security groups: Microsegmentation (e.g., bastion → app server only)
- Network Firewall: HTTPS allow, HTTP drop rule enforcement

---

## Integration Test Considerations

When fixing integration tests:

1. **Output Variables**: Verify all module outputs are correctly referenced (e.g., `module.vpc.vpc_id`)
2. **Resource Naming**: Ensure test assertions match actual resource names generated
3. **CIDR Blocks**: Validate subnet CIDR blocks (default: 10.0.1.0/24 for public, 10.0.2.0/24 for private)
4. **Default Values**: Many variables have defaults; tests should account for these
5. **Conditional Resources**: Bastion and app server instances are conditional on subnet availability
6. **KMS Keys**: Ensure KMS key ARN is correctly passed between modules
7. **Security Group Rules**: Verify ingress/egress rules match module configuration
8. **Route Table Associations**: Validate subnet-to-route-table relationships
9. **Deletion Windows**: DynamoDB tables configured for immediate deletion (0 days)
10. **AWS Constraints**: ACM PCA has 7-day minimum deletion window (AWS hard requirement)

