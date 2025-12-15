# ZTNA Scripts - Complete Implementation Guide

## 📦 What's Been Created

Three production-ready scripts for your ZTNA infrastructure:

| Script | Purpose | Time | When |
|--------|---------|------|------|
| `build.sh` | Validate code before deployment | 5 min | Before deploy |
| `deploy.sh` | Deploy infrastructure to AWS | 15-20 min | To go live |
| `destroy.sh` | Safely destroy infrastructure | 5-10 min | Cleanup |

All scripts are located in: `/Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS/scripts/`

---

## 🎯 Quick Start (5 Minutes)

### Make Scripts Executable
```bash
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS
chmod +x scripts/*.sh   # Already done
```

### Validate Your Infrastructure
```bash
./scripts/build.sh
```

Expected output: ✓ All modules validated successfully!

### Deploy Everything
```bash
./scripts/deploy.sh
```

Expected time: 15-20 minutes  
Expected output: ✓ All modules deployed successfully!

### Destroy When Done
```bash
./scripts/destroy.sh
```

Expected output: ✓ ZTNA infrastructure has been completely removed

---

## 📜 Script Details

### 1. BUILD SCRIPT - `./scripts/build.sh`

**Purpose:** Validate everything before deploying

**What it checks:**
- ✓ Terraform installed
- ✓ AWS CLI installed
- ✓ AWS credentials configured
- ✓ All Terraform syntax valid
- ✓ All modules format correctly
- ✓ Security issues (wildcard policies)
- ✓ Generates deployment plans

**Usage:**
```bash
./scripts/build.sh
```

**Output Example:**
```
╔════════════════════════════════════════════════════════════════╗
║         ZTNA Infrastructure Build & Validation Script          ║
╚════════════════════════════════════════════════════════════════╝

Step 1: Checking Prerequisites
✓ Terraform installed (Terraform v1.6.0 ...)
✓ AWS CLI installed
✓ AWS credentials valid (Account: 123456789, Region: eu-north-1)

Step 2: Formatting Terraform Code
✓ Formatted 11 directories

Step 3: Validating Terraform Modules
✓ Module: vpc
✓ Module: security
✓ Module: bootstrap
... (continues for all 11 modules)

Step 4: Validating Environment Configurations
✓ Environment: dev/vpc
✓ Environment: dev/security
... (continues for all 11 environments)

Step 5: Security Check - Looking for Wildcards
✓ No wildcard issues found

Step 6: Initializing Terraform State Backend
✓ VPC module initialized

Step 7: Generating Terraform Plans
✓ vpc plan created
✓ security plan created
... (one for each module)

Build Summary
✓ All modules validated successfully
✓ All environments validated successfully
✓ Build completed successfully!

Next steps:
1. Review plans:  terraform show terraform-plans/vpc.tfplan
2. Deploy:        ./scripts/deploy.sh
3. Destroy:       ./scripts/destroy.sh
```

**Troubleshooting:**
- If validation fails, check error messages and fix Terraform syntax
- If AWS credentials fail, run: `aws configure`
- If wildcards are found, see: `WILDCARD_REMEDIATION.md`

---

### 2. DEPLOY SCRIPT - `./scripts/deploy.sh`

**Purpose:** Deploy all infrastructure to AWS in correct order

**Deployment Order:**
```
Foundation:
  1. vpc               → Network foundation (VPC, subnets, routing)
  2. security          → IAM roles and KMS keys
  3. bootstrap         → S3 bucket for CloudTrail

Core Services:
  4. firewall          → AWS Network Firewall
  5. compute           → EC2 instances (Bastion, App)
  6. data_store        → DynamoDB table
  7. monitoring        → CloudTrail and CloudWatch

Security Hardening:
  8. vpc-endpoints     → Private AWS service endpoints
  9. secrets           → Secrets Manager
 10. rbac-authorization → Tag-based access control
 11. certificates      → mTLS certificates
```

**Usage:**
```bash
# Deploy all modules
./scripts/deploy.sh

# Dry run (see what would happen, no changes)
./scripts/deploy.sh --dry-run

# Deploy single module
./scripts/deploy.sh --module=vpc

# Destroy instead (same as destroy.sh)
./scripts/deploy.sh --destroy
```

**Features:**
- ✓ Confirmation prompt (prevents accidents)
- ✓ Automatic terraform init
- ✓ Dependency-aware (waits for dependent modules)
- ✓ Detailed logging
- ✓ Shows AWS resources after deployment
- ✓ Automatic approval (-auto-approve)

**Output Example:**
```
╔════════════════════════════════════════════════════════════════╗
║              ZTNA Infrastructure Deployment Script             ║
╚════════════════════════════════════════════════════════════════╝

Starting Full Deployment

Deployment Plan
Modules will be deployed in this order:
  1. vpc (status: NOT_DEPLOYED)
  2. security (status: NOT_DEPLOYED)
  3. bootstrap (status: NOT_DEPLOYED)
  ... (continues for all 11 modules)

Do you want to proceed? (yes/no): yes

ℹ Deploying: vpc
✓ vpc deployed

ℹ Deploying: security
✓ security deployed

... (continues for all modules)

Deployment Summary
✓ All modules deployed successfully

AWS Resources:
  VPC: vpc-12345678
  EC2: i-987654321

✓ Deployment completed!
```

**Time Estimates:**
- Full deployment: 15-20 minutes
- Individual module: 1-5 minutes
- Dry run: 1-2 minutes

**Troubleshooting:**
- Check deployment logs: `cat /tmp/<module>_apply.log`
- Common issues: AWS credentials, insufficient permissions, secrets not set
- If one module fails, fix and run: `./scripts/deploy.sh --module=<name>`

---

### 3. DESTROY SCRIPT - `./scripts/destroy.sh`

**Purpose:** Safely destroy all infrastructure with confirmation

**Destruction Order (Reverse of deployment):**
```
Security (destroyed first):
  1. certificates
  2. rbac-authorization
  3. secrets
  4. vpc-endpoints

Core Services:
  5. monitoring
  6. data_store
  7. compute
  8. firewall

Foundation (destroyed last):
  9. bootstrap
 10. security
 11. vpc
```

**Usage:**
```bash
# Destroy with confirmation (recommended)
./scripts/destroy.sh

# Destroy without confirmation (risky!)
./scripts/destroy.sh --force
```

**Features:**
- ✓ Two confirmation steps (prevents accidents!)
- ✓ Shows detailed list of what will be deleted
- ✓ Requires AWS account ID confirmation
- ✓ Destroys in correct reverse order
- ✓ Automatically cleans up terraform state
- ✓ Removes .terraform directories
- ✓ Removes lock files

**Output Example:**
```
╔════════════════════════════════════════════════════════════════╗
║            ZTNA Infrastructure Destruction Script             ║
╚════════════════════════════════════════════════════════════════╝

Destruction Plan
⚠️  WARNING: This will PERMANENTLY DELETE all AWS resources!

Modules will be destroyed in this order:
  1. certificates (will destroy)
  2. rbac-authorization (will destroy)
  ... (continues for all 11 modules)

Resources to be destroyed:
  - VPC and all subnets
  - EC2 instances (Bastion and App servers)
  - DynamoDB table
  - S3 buckets and contents
  - Network Firewall
  - KMS keys
  - IAM roles and policies
  - Secrets Manager secrets
  - VPC Endpoints
  - Certificates
  - CloudTrail logs

⚠  This action CANNOT be undone!

Type 'yes' to confirm destruction: yes
Type the AWS account ID (123456789) to confirm: 123456789

ℹ Destroying: certificates
✓ certificates destroyed

... (continues for all modules)

Destruction Summary
✓ All 11 module(s) destroyed successfully
✓ ZTNA infrastructure has been completely removed

Cleanup
✓ Removed terraform state files
✓ Removed .terraform directories
✓ Removed .terraform.lock files

✓ Destruction completed successfully!
You can now deploy again using: ./scripts/deploy.sh
```

**Time Estimates:**
- Full destruction: 5-10 minutes
- Cleanup: 1 minute

**Safety Features:**
1. Requires typing 'yes' to confirm
2. Requires entering AWS account ID to confirm
3. Shows detailed list of what will be deleted
4. Only used when explicitly requested
5. Cannot be accidentally triggered

---

## 🔧 Advanced Usage

### Update a Single Module

```bash
# 1. Make changes to module code
vim modules/vpc/vpc.tf

# 2. Validate
./scripts/build.sh

# 3. Review changes
terraform show terraform-plans/vpc.tfplan

# 4. Deploy only that module
./scripts/deploy.sh --module=vpc

# 5. Verify
aws ec2 describe-vpcs
```

### Debug Deployment

```bash
# Enable debug logging
TF_LOG=DEBUG ./scripts/deploy.sh

# Save logs to file
TF_LOG=DEBUG ./scripts/deploy.sh 2>&1 | tee deployment.log

# Check specific module logs
cat /tmp/vpc_apply.log
cat /tmp/compute_apply.log
```

### Partial Deployment

Deploy only foundation:
```bash
./scripts/deploy.sh --module=vpc
./scripts/deploy.sh --module=security
./scripts/deploy.sh --module=bootstrap
```

Deploy only compute:
```bash
./scripts/deploy.sh --module=firewall
./scripts/deploy.sh --module=compute
./scripts/deploy.sh --module=data_store
```

Deploy only security hardening:
```bash
./scripts/deploy.sh --module=vpc-endpoints
./scripts/deploy.sh --module=secrets
./scripts/deploy.sh --module=rbac-authorization
./scripts/deploy.sh --module=certificates
```

### Check Deployment Status

```bash
# List all deployed modules
find envs/dev -name terraform.tfstate -type f

# Show resources in specific module
terraform -chdir=envs/dev/vpc state list

# Show outputs from module
terraform -chdir=envs/dev/vpc output

# Check AWS resources
aws ec2 describe-instances
aws dynamodb list-tables
aws secretsmanager list-secrets
```

---

## 📋 Pre-Deployment Checklist

Before running `./scripts/deploy.sh`:

- [ ] Terraform installed (`terraform version`)
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Ran `./scripts/build.sh` successfully
- [ ] No wildcard warnings in build output
- [ ] Set secrets in `envs/dev/secrets/terraform.tfvars`:
  - [ ] `db_password` set
  - [ ] `api_key_1` set
  - [ ] `api_key_2` set
- [ ] Have AWS account ID ready (for destroy confirmation)

---

## 🚨 Emergency Procedures

### If Deployment Fails

```bash
# 1. Check the error log
cat /tmp/<module>_apply.log

# 2. Fix the issue (usually AWS permissions or secrets)

# 3. Retry full deployment
./scripts/deploy.sh

# OR retry specific module
./scripts/deploy.sh --module=<module_name>
```

### If You Need to Rollback

```bash
# Destroy current deployment
./scripts/destroy.sh

# Wait for destruction to complete

# Deploy fresh
./scripts/deploy.sh
```

### If Terraform State is Corrupted

```bash
# Remove state files and start fresh
rm -rf envs/dev/*/terraform.tfstate*
rm -rf envs/dev/*/.terraform

# Reinitialize and deploy
./scripts/deploy.sh
```

---

## 🎓 Complete Workflow Example

### First Time Setup

```bash
# 1. Clone/enter project
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS

# 2. Set AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# 3. Verify AWS access
aws sts get-caller-identity
# Should show your account info

# 4. Set secrets
nano envs/dev/secrets/terraform.tfvars
# Set: db_password, api_key_1, api_key_2

# 5. Build and validate
./scripts/build.sh
# Expected: ✓ Build completed successfully!

# 6. Deploy
./scripts/deploy.sh
# Expected: ✓ All modules deployed successfully!

# 7. Wait 15-20 minutes for deployment to complete

# 8. Verify deployment
aws ec2 describe-instances --output table
aws dynamodb list-tables

# 9. Your infrastructure is now live!
```

### Update and Redeploy

```bash
# 1. Make changes to Terraform code
vim modules/vpc/vpc.tf

# 2. Validate changes
./scripts/build.sh

# 3. Review what changed
terraform show terraform-plans/vpc.tfplan

# 4. Deploy changes
./scripts/deploy.sh --module=vpc

# 5. Verify
aws ec2 describe-vpcs
```

### Cleanup

```bash
# 1. Destroy all infrastructure
./scripts/destroy.sh

# 2. Confirm when prompted:
#    - Type: yes
#    - Type: your AWS account ID

# 3. Wait 5-10 minutes for destruction

# 4. Verify cleanup
aws ec2 describe-instances
# Should show no instances
```

---

## 📊 Module Dependency Graph

```
vpc (foundation)
  ↓
security (IAM + KMS)
  ├→ bootstrap (S3 for CloudTrail)
  ├→ compute (EC2 - needs IAM + KMS)
  ├→ firewall (Network Firewall)
  ├→ monitoring (logs + monitoring)
  ├→ vpc-endpoints (needs VPC)
  ├→ secrets (needs KMS + IAM)
  ├→ rbac-authorization (needs IAM)
  └→ certificates (mTLS certs)
```

**Key Dependencies:**
- `vpc` → Foundation (everything depends on it)
- `security` → Provides IAM roles and KMS keys
- `compute` → Depends on vpc + security
- `secrets` → Depends on security (KMS + IAM)

All scripts handle these dependencies automatically!

---

## 🛠️ Terraform Commands (Manual)

If you need to run Terraform manually:

```bash
# Go to module directory
cd envs/dev/vpc

# Initialize Terraform
terraform init

# See what would change
terraform plan

# Apply changes
terraform apply

# Destroy module
terraform destroy

# Show current resources
terraform state list

# Show specific resource details
terraform show

# Show module outputs
terraform output
```

---

## 🔍 Troubleshooting Guide

| Issue | Solution |
|-------|----------|
| `Terraform not found` | Install from https://www.terraform.io/downloads.html |
| `AWS credentials not configured` | Run: `aws configure` |
| `Deployment fails halfway` | Run: `./scripts/deploy.sh` again to retry |
| `Module fails with permissions error` | Check AWS IAM permissions or use AdministratorAccess |
| `Wildcard warnings in build` | See: `WILDCARD_REMEDIATION.md` |
| `Secrets not set` | Edit: `envs/dev/secrets/terraform.tfvars` |
| `State file corrupted` | Remove and redeploy: `rm -rf envs/dev/*/terraform.tfstate*` |
| `Cannot destroy resource` | Manually delete in AWS Console or run: `./scripts/destroy.sh --force` |

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `scripts/README.md` | Complete script documentation (you are here) |
| `SCRIPTS_QUICK_START.md` | Quick start guide for scripts |
| `DEPLOYMENT_GUIDE.md` | Detailed deployment procedures |
| `WILDCARD_REMEDIATION.md` | Fix security policy wildcards |
| `FINAL_STATUS_REPORT.md` | Project overview |
| `00_START_HERE.md` | Documentation index |

---

## ✅ Success Criteria

After `./scripts/deploy.sh`:

✓ All 11 modules deployed without errors  
✓ Terraform output shows: "✓ All modules deployed successfully!"  
✓ AWS resources created: `aws ec2 describe-instances`  
✓ DynamoDB table exists: `aws dynamodb list-tables`  
✓ Secrets stored: `aws secretsmanager list-secrets`  
✓ CloudTrail logging: `aws cloudtrail describe-trails`  

---

## 🎉 You're Ready!

```bash
# Let's deploy your ZTNA infrastructure!
cd /Users/y3gi/uni_projects/sem_3/Zero_Trust_AWS
./scripts/build.sh && ./scripts/deploy.sh
```

**Estimated time to deployment:** 30-40 minutes (including wait time)

Good luck! 🚀

