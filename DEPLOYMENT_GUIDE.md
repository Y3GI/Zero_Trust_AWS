# ZTNA Implementation: Next Actions & Deployment Guide

## 📋 Current State Summary

✅ **COMPLETE (11 modules, all linked to env/dev):**
- vpc
- security (IAM + KMS)
- bootstrap (S3 + CloudTrail)
- compute (EC2)
- data_store (DynamoDB)
- firewall (Network Firewall)
- monitoring (CloudWatch + Logs)
- vpc-endpoints (8 private endpoints)
- secrets (Secrets Manager)
- rbac-authorization (Tag-based access control)
- certificates (mTLS + internal PKI)

✅ **LINKED (All 11 modules wired to envs/dev/):**
- vpc → vpc-endpoints connectivity
- security → secrets, rbac-authorization, certificates
- bootstrap → CloudTrail S3
- compute → all security groups + IAM roles
- All modules use remote state data sources

✅ **DOCUMENTED:**
- 7 comprehensive documentation files (2,850+ lines)
- Architecture diagrams and gap analysis
- ZTNA completeness checklist (85% ready)

---

## ⚠️ Immediate Action Items (Before Deployment)

### Priority 1: Fix Security Issues (1-2 hours)

#### 1a. Remove Wildcard Policies
**Status:** MUST DO before production

**Files to fix:**
- `modules/vpc-endpoints/main.tf` - S3 endpoint policy
- `modules/rbac-authorization/main.tf` - KMS/Secrets actions
- `modules/secrets/main.tf` - Resource policies

**What to do:**
```bash
# Use the WILDCARD_REMEDIATION.md guide to:
1. Replace Action = "*" with specific actions
2. Replace Resource = "*" with specific ARNs
3. Replace Principal = "*" with specific services/roles
```

**Example fix for S3 endpoint:**
```hcl
# Old (too permissive)
policy = jsonencode({
  Statement = [{
    Principal = "*"
    Action = "s3:*"
    Resource = "*"
  }]
})

# New (restrictive)
policy = jsonencode({
  Statement = [{
    Principal = { Service = "cloudtrail.amazonaws.com" }
    Action = ["s3:PutObject", "s3:GetBucketVersioning"]
    Resource = [
      "arn:aws:s3:::${var.cloudtrail_bucket_name}",
      "arn:aws:s3:::${var.cloudtrail_bucket_name}/*"
    ]
  }]
})
```

**Validation:**
```bash
cd envs/dev
terraform validate
terraform plan | grep -i "policy"  # Review all policy changes
```

---

#### 1b. Create variables.tf Files for New Modules
**Status:** MUST DO for proper configuration

**Create:** `envs/dev/secrets/variables.tf`
```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "api_key_1" {
  description = "API key 1"
  type        = string
  sensitive   = true
}

variable "api_key_2" {
  description = "API key 2"
  type        = string
  sensitive   = true
}
```

**Create:** `envs/dev/vpc-endpoints/variables.tf`
```hcl
variable "cloudtrail_bucket_name" {
  description = "S3 bucket for CloudTrail"
  type        = string
  default     = ""  # Will use linked output if empty
}
```

**Create:** `envs/dev/rbac-authorization/variables.tf`
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
```

**Create:** `envs/dev/certificates/variables.tf`
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
```

---

#### 1c. Create terraform.tfvars for Secrets
**Status:** MUST DO to set sensitive values

**Create:** `envs/dev/secrets/terraform.tfvars`
```hcl
db_password = "YourSecurePassword123!"
api_key_1   = "sk-your-api-key-1"
api_key_2   = "sk-your-api-key-2"
```

**Or use environment variables:**
```bash
export TF_VAR_db_password="YourSecurePassword123!"
export TF_VAR_api_key_1="sk-your-api-key-1"
export TF_VAR_api_key_2="sk-your-api-key-2"
```

---

### Priority 2: Add Missing Optional Modules (2-3 hours each)

#### 2a. GuardDuty (Threat Detection)
**Why:** Detects compromises - essential for "Assume Breach" principle
**Effort:** LOW (simple module)
**Cost:** $30-40/month
**Timeline:** After core deployment working

**Create:** `modules/threat-detection/main.tf`
```hcl
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = {
    Environment = var.environment
    Module      = "GuardDuty"
  }
}

# Connect to Security Hub
resource "aws_securityhub_finding_aggregator" "main" {
  linking_mode = "ALL_REGIONS"
}

output "detector_id" {
  value = aws_guardduty_detector.main.id
}
```

#### 2b. AWS Config (Compliance Tracking)
**Why:** Continuous compliance monitoring
**Effort:** LOW
**Cost:** $1-3/month
**Timeline:** After GuardDuty

#### 2c. Network ACLs (Additional Filtering)
**Why:** Stateless filtering layer
**Effort:** MEDIUM
**Timeline:** Week 2

---

## 🚀 Deployment Plan (Step-by-Step)

### Phase 1: Pre-Deployment Validation (Day 0)

```bash
# 1. Enter the dev environment
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/envs/dev

# 2. Initialize Terraform (creates backend)
terraform init

# 3. Validate all modules
terraform validate

# 4. Check for syntax errors
terraform fmt -recursive

# 5. Plan full deployment (see what will be created)
terraform plan -out=tfplan

# 6. Review the plan carefully
terraform show tfplan | head -100  # Review first 100 lines
```

### Phase 2: Deploy Foundation (Day 1 - Morning)

Deploy in this order (dependencies matter):

```bash
# 1. Deploy VPC first (foundation)
cd vpc
terraform apply
cd ..

# 2. Deploy Security (IAM + KMS)
cd security
terraform apply
cd ..

# 3. Deploy Bootstrap (S3 + CloudTrail)
cd bootstrap
terraform apply
cd ..
```

**Validation:**
```bash
# Verify S3 bucket created
aws s3api list-buckets | grep cloudtrail

# Verify KMS key created
aws kms list-keys
```

### Phase 3: Deploy Compute & Services (Day 1 - Afternoon)

```bash
# 1. Deploy Firewall
cd firewall
terraform apply
cd ..

# 2. Deploy Compute (EC2)
cd compute
terraform apply
cd ..

# 3. Deploy Data Store (DynamoDB)
cd data_store
terraform apply
cd ..

# 4. Deploy Monitoring
cd monitoring
terraform apply
cd ..
```

**Validation:**
```bash
# Check EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}'

# Check DynamoDB
aws dynamodb list-tables
```

### Phase 4: Deploy Security Enhancements (Day 2 - Morning)

```bash
# 1. Deploy VPC Endpoints
cd vpc-endpoints
terraform apply
cd ..

# 2. Deploy Secrets
cd secrets
terraform apply
cd ..

# 3. Deploy RBAC Authorization
cd rbac-authorization
terraform apply
cd ..

# 4. Deploy Certificates
cd certificates
terraform apply
cd ..
```

**Validation:**
```bash
# Check VPC Endpoints
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].{ID:VpcEndpointId,Service:ServiceName}'

# Check Secrets
aws secretsmanager list-secrets

# Check Certificates
aws acm list-certificates
```

---

## ✅ Post-Deployment Verification (Day 2 - Afternoon)

### Test 1: Network Connectivity
```bash
# SSH into Bastion
BASTION_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bastion" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

ssh -i /path/to/key.pem ec2-user@$BASTION_IP

# From bastion, test app server connectivity
ssh app-server  # Should work via private IP

# Test VPC Endpoint (DNS should resolve)
nslookup secretsmanager.us-east-1.amazonaws.com
```

### Test 2: Secrets Retrieval
```bash
# From app server, retrieve a secret
aws secretsmanager get-secret-value \
  --secret-id db-credentials \
  --query 'SecretString' | jq .

# Should return encrypted credential
```

### Test 3: Encryption Verification
```bash
# Verify KMS is used
aws s3 head-bucket \
  --bucket $(aws s3api list-buckets --query 'Buckets[?contains(Name, `cloudtrail`)].Name' --output text) \
  --query 'ServerSideEncryption'

# Should show "aws:kms"
```

### Test 4: CloudTrail Logging
```bash
# Check if CloudTrail is logging
aws cloudtrail describe-trails --query 'trailList[].TrailARN'

# View recent logs (wait 5-15 minutes after deployment)
aws s3api list-objects-v2 \
  --bucket $(aws s3api list-buckets --query 'Buckets[?contains(Name, `cloudtrail`)].Name' --output text) \
  --prefix "AWSLogs" \
  --max-items 10
```

### Test 5: RBAC Policy Enforcement
```bash
# Try to access KMS with wrong role (should fail)
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/invalid --role-session-name test

# Try with correct role (should work)
aws sts assume-role \
  --role-arn $(aws ec2 describe-instances --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text | sed 's/:instance-profile\//:role\//' | sed 's/\/.*/\/') \
  --role-session-name test
```

---

## 🔄 Rollback Plan (If Something Goes Wrong)

### Quick Rollback
```bash
# Destroy specific module
cd envs/dev/problematic-module
terraform destroy

# Or destroy all (careful!)
cd envs/dev
terraform destroy
```

### Selective Rollback
```bash
# Remove specific resource from state
terraform state rm 'module.secrets.aws_secretsmanager_secret.db_credentials'

# Then reapply
terraform apply
```

---

## 📊 Configuration Files You Need

### 1. `envs/dev/terraform.tfvars` (Already exists or create)
```hcl
# General
environment = "dev"
region      = "us-east-1"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# Instance Configuration
instance_type = "t3.micro"
```

### 2. `envs/dev/secrets/terraform.tfvars` (Needs creation)
```hcl
db_password = "YourSecurePassword123!"
api_key_1   = "sk-1234567890"
api_key_2   = "sk-0987654321"
```

### 3. `.gitignore` (For sensitive files)
```
terraform.tfvars
*.tfstate
*.tfstate.backup
*.tfvars
!example.tfvars
```

---

## 📈 Progress Tracking

Use this checklist to track deployment progress:

### Pre-Deployment
- [ ] Fix all wildcard (*) policies
- [ ] Create variables.tf for new modules
- [ ] Create terraform.tfvars for secrets
- [ ] Run `terraform validate`
- [ ] Run `terraform plan` and review

### Deployment Day 1
- [ ] Deploy VPC
- [ ] Deploy Security
- [ ] Deploy Bootstrap
- [ ] Deploy Firewall
- [ ] Deploy Compute
- [ ] Deploy Data Store
- [ ] Deploy Monitoring

### Deployment Day 2
- [ ] Deploy VPC Endpoints
- [ ] Deploy Secrets
- [ ] Deploy RBAC Authorization
- [ ] Deploy Certificates
- [ ] Run all validation tests
- [ ] Document any issues

### Post-Deployment
- [ ] Network connectivity test ✅
- [ ] Secrets retrieval test ✅
- [ ] Encryption verification ✅
- [ ] CloudTrail logging test ✅
- [ ] RBAC policy test ✅

### Week 2+ (Optional Enhancements)
- [ ] Add GuardDuty (Threat Detection)
- [ ] Add AWS Config (Compliance)
- [ ] Add Network ACLs
- [ ] Optimize costs
- [ ] Performance testing

---

## 📞 Troubleshooting Guide

### Issue: "Error: Error acquiring the state lock"
**Solution:**
```bash
# Remove lock file
rm -f .terraform/.lock.hcl

# Or force unlock
terraform force-unlock <LOCK_ID>
```

### Issue: "Error: VPC Endpoint policy is invalid"
**Solution:**
```bash
# Validate JSON policy
cat policy.json | jq .

# Check for wildcards
grep -n "\*" policy.json
```

### Issue: "Error: Credentials not found"
**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Or set manually
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

### Issue: "Error: Resource already exists"
**Solution:**
```bash
# Import existing resource
terraform import 'module.vpc.aws_vpc.main' vpc-123456

# Or remove from state and recreate
terraform state rm 'module.vpc.aws_vpc.main'
terraform apply
```

---

## 🎯 Success Criteria

Your ZTNA deployment is successful when:

✅ All 11 modules deployed without errors  
✅ All resources created in AWS account  
✅ Network connectivity working (Bastion → App → DB)  
✅ Secrets retrievable from Secrets Manager  
✅ CloudTrail logging all API calls  
✅ KMS encryption enabled on all data at rest  
✅ VPC Endpoints all active and accessible  
✅ RBAC policies enforcing least privilege  
✅ mTLS certificates generated and ready  
✅ All validation tests passing  

---

## 💡 Tips & Best Practices

1. **Always plan before applying**
   ```bash
   terraform plan -out=tfplan  # Review before applying
   terraform apply tfplan
   ```

2. **Use remote state for team collaboration**
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-terraform-state"
       key    = "ztna/dev/terraform.tfstate"
       region = "us-east-1"
     }
   }
   ```

3. **Tag everything for cost tracking**
   ```hcl
   tags = {
     Environment = "dev"
     Module      = "vpc"
     CostCenter  = "security"
   }
   ```

4. **Use workspaces for multiple environments**
   ```bash
   terraform workspace new dev
   terraform workspace new prod
   terraform workspace select prod
   ```

5. **Monitor costs from day 1**
   ```bash
   # Estimate costs
   terraform plan | terraform-cost-estimation
   ```

---

## ✨ Next Steps (In Priority Order)

**This Week:**
1. ✅ Fix wildcard policies (security critical)
2. ✅ Create missing variables.tf files
3. ✅ Run `terraform validate`
4. ✅ Deploy Phase 1-4 modules

**Next Week:**
5. ⏳ Verify all post-deployment tests pass
6. ⏳ Add GuardDuty for threat detection
7. ⏳ Add AWS Config for compliance monitoring
8. ⏳ Create monitoring dashboards

**Later:**
9. ⏳ Add Network ACLs
10. ⏳ Set up multi-region HA
11. ⏳ Implement CI/CD pipeline
12. ⏳ Optimize costs

---

## 📚 Reference Documents

All needed documentation is in `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/`:

- ✅ `ZTNA_COMPLETENESS_CHECKLIST.md` - What's done, what's left
- ✅ `WILDCARD_REMEDIATION.md` - How to fix * policies
- ✅ `ARCHITECTURE_DIAGRAMS.md` - Visual architecture
- ✅ `IMPLEMENTATION_SUMMARY.md` - Complete implementation details
- ✅ `GAP_ANALYSIS.md` - What was missing

**You're 85% done. Let's get to 100%!**

