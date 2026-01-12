# Deployment Guide

Step-by-step instructions for deploying the Zero Trust AWS infrastructure.

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.7.5 | [terraform.io/downloads](https://www.terraform.io/downloads) |
| AWS CLI | >= 2.0 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| Go | >= 1.21 | [go.dev/dl](https://go.dev/dl/) (for testing) |
| Make | any | Pre-installed on macOS/Linux |

### AWS Configuration

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

Required AWS permissions:
- EC2, VPC, IAM, KMS, S3, DynamoDB, Secrets Manager
- CloudTrail, CloudWatch, Network Firewall, ACM
- Full admin access recommended for initial deployment

## Deployment Methods

### Method 1: Using Make (Recommended)

```bash
# View available commands
make help

# Deploy infrastructure
make deploy

# Destroy infrastructure
make destroy
```

### Method 2: Using Scripts

```bash
# Build and validate
bash scripts/build.sh

# Deploy
bash scripts/deploy.sh

# Destroy
bash scripts/destroy.sh
```

### Method 3: Manual Terraform

Deploy modules in dependency order:

```bash
# 1. Bootstrap (first - creates state bucket)
cd envs/dev/bootstrap
terraform init
terraform plan
terraform apply

# 2. Security
cd ../security
terraform init
terraform plan
terraform apply

# 3. VPC
cd ../vpc
terraform init
terraform plan
terraform apply

# Continue with remaining modules...
```

## Deployment Order

Modules must be deployed in this order due to dependencies:

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 1: Foundation (No Dependencies)                           │
├─────────────────────────────────────────────────────────────────┤
│  1. bootstrap      - S3 buckets for state and CloudTrail        │
│  2. security       - IAM roles and KMS keys                     │
│  3. vpc            - Network infrastructure                     │
│  4. certificates   - ACM Private CA                             │
│  5. rbac-authorization - IAM policies                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Phase 2: Dependent Modules                                       │
├─────────────────────────────────────────────────────────────────┤
│  6. data_store     - DynamoDB (needs: security)                 │
│  7. firewall       - Network Firewall (needs: vpc)              │
│  8. secrets        - Secrets Manager (needs: security)          │
│  9. vpc-endpoints  - VPC Endpoints (needs: vpc, bootstrap)      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Phase 3: Compute & Monitoring                                    │
├─────────────────────────────────────────────────────────────────┤
│ 10. compute        - EC2 (needs: vpc, security)                 │
│ 11. monitoring     - CloudTrail/CloudWatch (needs: all above)   │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Configuration

### Development Environment (`envs/dev/`)

Each module in `envs/dev/` is configured to:
1. Use local backend for state
2. Reference dependent modules via `terraform_remote_state`
3. Deploy to `eu-north-1` region

Example module structure:
```
envs/dev/vpc/
├── main.tf          # Module configuration
├── variables.tf     # Input variables (if needed)
└── terraform.tfstate # Local state (after apply)
```

### Test Environments (`envs/test/`)

- **integration/**: Mock values for isolated module testing
- **e2e/**: Local state references for full stack testing

## Post-Deployment Verification

### Verify Deployed Resources

```bash
# List VPCs
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"

# List S3 buckets
aws s3 ls | grep ztna

# List IAM roles
aws iam list-roles | grep ztna

# List EC2 instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
```

### Run Validation Tests

```bash
# Unit tests (no AWS deployment)
make test

# Integration tests (validates deployed resources)
make test-integration
```

## Destroy Infrastructure

### Using Make

```bash
make destroy
```

### Manual Destruction

Destroy in **reverse dependency order**:

```bash
# 1. Monitoring (last deployed, first destroyed)
cd envs/dev/monitoring && terraform destroy -auto-approve

# 2. Compute
cd ../compute && terraform destroy -auto-approve

# 3. VPC Endpoints
cd ../vpc-endpoints && terraform destroy -auto-approve

# 4. Secrets
cd ../secrets && terraform destroy -auto-approve

# 5. Firewall
cd ../firewall && terraform destroy -auto-approve

# 6. Data Store
cd ../data_store && terraform destroy -auto-approve

# 7. RBAC
cd ../rbac-authorization && terraform destroy -auto-approve

# 8. Certificates
cd ../certificates && terraform destroy -auto-approve

# 9. VPC
cd ../vpc && terraform destroy -auto-approve

# 10. Security
cd ../security && terraform destroy -auto-approve

# 11. Bootstrap (first deployed, last destroyed)
cd ../bootstrap && terraform destroy -auto-approve
```

### Clean Up Local Files

```bash
make clean
```

## CI/CD Deployment

### GitHub Actions Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `doploy_workflow.yml` | Deploy infrastructure | Manual (`workflow_dispatch`) |
| `destroy_workflow.yml` | Destroy infrastructure | Manual (`workflow_dispatch`) |

### Required Secrets

Configure these secrets in GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN for GitHub Actions OIDC |

### OIDC Configuration

GitHub Actions uses OIDC to assume an IAM role without static credentials:

```hcl
# IAM role trust policy for GitHub Actions
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"
        }
      }
    }
  ]
}
```

## Troubleshooting

### Common Issues

**State lock error**:
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

**Resource already exists**:
```bash
# Import existing resource
terraform import aws_vpc.main vpc-12345678
```

**Permission denied**:
```bash
# Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USER \
  --action-names ec2:CreateVpc
```

**Dependency errors**:
- Ensure modules are deployed in correct order
- Verify remote state references point to existing state files

### Debug Mode

```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform apply

# Check specific module
cd envs/dev/vpc && terraform plan -out=plan.out
terraform show plan.out
```

## Cost Considerations

### Estimated Monthly Costs (Development)

| Resource | Estimated Cost |
|----------|---------------|
| NAT Gateway | ~$32/month |
| Network Firewall | ~$90/month |
| EC2 (t3.micro x2) | ~$15/month |
| VPC Endpoints (8x) | ~$56/month |
| S3 + DynamoDB | ~$5/month |
| ACM Private CA | ~$400/month |
| **Total** | **~$600/month** |

### Cost Optimization

- Use smaller instance types for dev
- Consider disabling ACM Private CA when not needed
- Reduce VPC endpoints if not all services are required
- Use single AZ for development (expand for production)
