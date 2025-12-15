# ZTNA Scripts - Quick Start Guide

## 🚀 One-Minute Overview

You now have 3 powerful scripts to manage your ZTNA infrastructure:

```bash
./scripts/build.sh      # Validate everything (run before deploy)
./scripts/deploy.sh     # Deploy to AWS
./scripts/destroy.sh    # Destroy infrastructure
```

---

## ✅ Prerequisites (One-Time Setup)

Before running any scripts:

```bash
# 1. Install Terraform
brew install terraform    # macOS
# or download from: https://www.terraform.io/downloads.html

# 2. Install AWS CLI
brew install awscli       # macOS
# or download from: https://aws.amazon.com/cli/

# 3. Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# 4. Verify everything works
aws sts get-caller-identity
terraform version
```

---

## 🎯 Typical 3-Step Workflow

### Step 1: Build & Validate (5 minutes)

```bash
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS
./scripts/build.sh
```

**What it does:**
- ✓ Validates all Terraform code
- ✓ Checks for syntax errors
- ✓ Scans for security issues (wildcards)
- ✓ Generates deployment plans

**Expected output:**
```
✓ Terraform installed
✓ AWS CLI installed
✓ AWS credentials valid (Account: 123456789, Region: eu-north-1)
✓ Formatted 11 directories
✓ Module: vpc
✓ Module: security
... (continues for all 11 modules)
✓ All modules validated successfully
✓ Build completed successfully!
```

### Step 2: Deploy (15-20 minutes)

```bash
./scripts/deploy.sh
```

**What it does:**
- ✓ Deploys all 11 modules in correct order
- ✓ Handles dependencies automatically
- ✓ Creates AWS resources (VPC, EC2, DynamoDB, etc.)
- ✓ Initializes state management

**Expected output:**
```
Deployment Plan
Modules will be deployed in this order:
  1. vpc (status: NOT_DEPLOYED)
  2. security (status: NOT_DEPLOYED)
  ... (all 11 modules)

Do you want to proceed? (yes/no): yes

ℹ Deploying: vpc
✓ vpc deployed

ℹ Deploying: security
✓ security deployed

... (continues for all modules)

✓ All modules deployed successfully!
```

### Step 3: Verify (5 minutes)

```bash
# Check EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' --output table

# Check DynamoDB
aws dynamodb list-tables

# Check VPC
aws ec2 describe-vpcs
```

---

## 🛠️ Advanced Usage

### Dry Run (see what would happen without making changes)

```bash
./scripts/deploy.sh --dry-run
```

### Deploy Only One Module

```bash
./scripts/deploy.sh --module=vpc
./scripts/deploy.sh --module=compute
./scripts/deploy.sh --module=secrets
```

### Destroy Everything

```bash
./scripts/destroy.sh
```

**What it does:**
- ✓ Confirms destruction 2 times (prevents accidents!)
- ✓ Destroys all infrastructure in correct reverse order
- ✓ Cleans up Terraform state files
- ✓ Removes temporary directories

**Expected output:**
```
⚠️  WARNING: This will PERMANENTLY DELETE all AWS resources!

Destruction Plan
Modules will be destroyed in this order:
  1. certificates (will destroy)
  2. rbac-authorization (will destroy)
  ... (all 11 modules in reverse order)

Type 'yes' to confirm destruction: yes
Type the AWS account ID (123456789) to confirm: 123456789

ℹ Destroying: certificates
✓ certificates destroyed

... (continues for all modules)

✓ All modules destroyed successfully!
```

### Force Destroy (no confirmation)

```bash
./scripts/destroy.sh --force
```

---

## 📊 Deployment Order

All 11 modules deploy in dependency order:

**Foundation (deployed first):**
1. VPC
2. Security (IAM + KMS)
3. Bootstrap (S3 + CloudTrail)

**Core Services:**
4. Firewall
5. Compute (EC2)
6. Data Store (DynamoDB)
7. Monitoring

**Security Hardening (deployed last):**
8. VPC Endpoints
9. Secrets Manager
10. RBAC Authorization
11. Certificates

---

## ⚠️ Important: Secrets Configuration

Before first deployment, set your secrets:

```bash
# Edit the secrets file
nano envs/dev/secrets/terraform.tfvars

# Add your actual values (replace examples):
db_password = "YourSecurePassword123!"
api_key_1   = "sk-your-api-key-1"
api_key_2   = "sk-your-api-key-2"

# Or use environment variables
export TF_VAR_db_password="YourSecurePassword123!"
export TF_VAR_api_key_1="sk-your-api-key-1"
export TF_VAR_api_key_2="sk-your-api-key-2"
```

---

## 🔍 Troubleshooting

### Build validation fails

```bash
# Check what module failed
./scripts/build.sh

# Run terraform validate on that module
terraform -chdir=envs/dev/vpc validate

# Fix any syntax errors and re-run build
./scripts/build.sh
```

### Deployment fails halfway

```bash
# Check the error log
cat /tmp/<module>_apply.log

# Fix the issue (usually AWS credentials or permissions)

# Continue deployment from where it failed
./scripts/deploy.sh

# Or retry a specific module
./scripts/deploy.sh --module=<module_name>
```

### Wildcard warnings

The build script warns about wildcard (*) in policies:

```bash
# This is a security issue - FIX IT!
# See: WILDCARD_REMEDIATION.md
grep -r 'Action.*\*' modules/
grep -r 'Resource.*\*' modules/
```

### AWS credentials error

```bash
# Verify credentials are configured
aws sts get-caller-identity

# If error, configure again
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="eu-north-1"
```

---

## 📋 Common Commands Reference

```bash
# BUILDING
./scripts/build.sh                          # Validate everything
./scripts/build.sh 2>&1 | tee build.log    # Save output to file

# DEPLOYING
./scripts/deploy.sh                         # Deploy all modules
./scripts/deploy.sh --dry-run               # Dry run (no changes)
./scripts/deploy.sh --module=vpc            # Deploy single module

# DESTROYING
./scripts/destroy.sh                        # Destroy all (with confirmation)
./scripts/destroy.sh --force                # Destroy without confirmation

# CHECKING STATUS
aws ec2 describe-instances --output table
aws dynamodb list-tables
aws secretsmanager list-secrets
aws ec2 describe-vpcs

# DEBUGGING
TF_LOG=DEBUG ./scripts/deploy.sh            # Enable debug logging
tail -f /tmp/vpc_apply.log                  # Watch deployment logs
terraform show terraform-plans/vpc.tfplan   # View specific plan

# MANUAL TERRAFORM
terraform -chdir=envs/dev/vpc plan          # Manual plan for module
terraform -chdir=envs/dev/vpc apply         # Manual apply for module
terraform -chdir=envs/dev/vpc state list    # List resources in state
terraform -chdir=envs/dev/vpc output        # Show outputs
```

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| Build/validate | 5 min |
| Deploy all | 15-20 min |
| Deploy single module | 1-5 min |
| Dry run | 1-2 min |
| Destroy all | 5-10 min |
| **Total (first time)** | **30-40 min** |

---

## 🎓 Example: Full Deployment Workflow

```bash
# Start from project root
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS

# 1. Build and validate (5 minutes)
./scripts/build.sh

# Output should show: ✓ Build completed successfully!

# 2. Check for warnings (especially wildcards)
grep -r 'Action.*\*' modules/ || echo "No wildcards found"

# 3. Deploy all infrastructure (15-20 minutes)
./scripts/deploy.sh

# When prompted, type "yes" to confirm

# Wait for all modules to deploy...
# Output should show: ✓ All modules deployed successfully!

# 4. Verify deployment
aws ec2 describe-instances --output table
aws dynamodb list-tables

# 5. Your infrastructure is now live!

# Later... when done testing, destroy everything
./scripts/destroy.sh

# When prompted:
# 1. Type: yes
# 2. Type: your AWS account ID
# 3. Wait for destruction to complete

echo "Infrastructure destroyed!"
```

---

## 📚 More Information

See these files for detailed information:

- `scripts/README.md` - Complete documentation for all scripts
- `DEPLOYMENT_GUIDE.md` - Step-by-step deployment procedures
- `WILDCARD_REMEDIATION.md` - Fix security policy issues
- `FINAL_STATUS_REPORT.md` - Project overview
- `00_START_HERE.md` - Documentation index

---

## ✨ What You Get After Deployment

✅ 3-tier VPC with security  
✅ EC2 instances (Bastion + App)  
✅ DynamoDB database  
✅ S3 bucket with CloudTrail logging  
✅ Network Firewall  
✅ KMS encryption  
✅ Secrets Manager  
✅ VPC Endpoints (8 endpoints)  
✅ RBAC/ABAC policies  
✅ Internal PKI + mTLS certificates  
✅ Complete audit trails  
✅ CloudWatch monitoring  

**All for ~$95-140/month!**

---

## 🚀 Ready?

```bash
# Let's go!
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS
./scripts/build.sh
./scripts/deploy.sh
```

Good luck! 🎉

