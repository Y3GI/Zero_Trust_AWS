#!/bin/bash

################################################################################
# ZTNA Infrastructure Scripts README
# Purpose: Documentation for build, deploy, and destroy scripts
# Generated: 2025-12-15
################################################################################

# This file is created as a shell script so it can be made executable
# But it serves as comprehensive documentation for all scripts

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════════╗
║           ZTNA Infrastructure Build, Deploy, & Destroy Scripts            ║
║                        Complete Usage Guide                               ║
╚════════════════════════════════════════════════════════════════════════════╝

## 📋 Quick Start

Three main scripts handle your entire ZTNA infrastructure lifecycle:

  1. ./scripts/build.sh       → Validate and prepare for deployment
  2. ./scripts/deploy.sh      → Deploy infrastructure to AWS
  3. ./scripts/destroy.sh     → Destroy infrastructure and clean up

### Typical Workflow

  Step 1: Make changes to Terraform files
  Step 2: Run ./scripts/build.sh          (validate)
  Step 3: Run ./scripts/deploy.sh         (deploy)
  Step 4: Test your infrastructure
  Step 5: Run ./scripts/destroy.sh        (cleanup when done)


═══════════════════════════════════════════════════════════════════════════════
  BUILD SCRIPT: ./scripts/build.sh
═══════════════════════════════════════════════════════════════════════════════

PURPOSE
  Validates all Terraform code, checks for issues, and prepares for deployment.
  This should be run before deployment to catch errors early.

USAGE
  ./scripts/build.sh

WHAT IT DOES
  ✓ Checks prerequisites (Terraform, AWS CLI installed)
  ✓ Verifies AWS credentials are configured
  ✓ Formats all Terraform files (terraform fmt)
  ✓ Validates all modules (terraform validate)
  ✓ Validates all env/dev configurations
  ✓ Checks for security issues (wildcard policies)
  ✓ Generates Terraform plan files
  ✓ Creates terraform-plans/ directory

OUTPUT
  - Colored output with success/error indicators
  - terraform-plans/ directory with .tfplan files
  - Validation report showing status of all modules

EXAMPLE OUTPUT
  ✓ Terraform installed
  ✓ AWS CLI installed
  ✓ AWS credentials valid (Account: 123456789, Region: eu-north-1)
  ✓ Formatted 11 directories
  ✓ Module: vpc
  ✓ Module: security
  ... (all modules)
  ✓ Environment: dev/vpc
  ✓ Environment: dev/security
  ... (all environments)

TROUBLESHOOTING
  If validation fails:
    1. Check error messages in output
    2. Run: terraform validate -chdir=<failing_module>
    3. Fix syntax errors in the module
    4. Re-run build.sh


═══════════════════════════════════════════════════════════════════════════════
  DEPLOY SCRIPT: ./scripts/deploy.sh
═══════════════════════════════════════════════════════════════════════════════

PURPOSE
  Deploys all ZTNA infrastructure to AWS in correct dependency order.
  Modules are deployed in sequence to ensure dependencies are satisfied.

USAGE
  ./scripts/deploy.sh                    → Deploy all modules
  ./scripts/deploy.sh --dry-run          → Show what would happen (no changes)
  ./scripts/deploy.sh --module=vpc       → Deploy only specific module
  ./scripts/deploy.sh --destroy          → Destroy all modules (alias)

DEPLOYMENT ORDER
  Modules are deployed in this sequence (respects dependencies):

  Phase 1 - Foundation
    1. vpc                  → VPC, subnets, routing (foundation)
    2. security             → IAM roles, KMS keys
    3. bootstrap            → S3 bucket for CloudTrail

  Phase 2 - Core Services
    4. firewall             → AWS Network Firewall
    5. compute              → EC2 instances
    6. data_store           → DynamoDB table
    7. monitoring           → CloudTrail, VPC Logs, CloudWatch

  Phase 3 - Security Hardening
    8. vpc-endpoints        → 8 private AWS service endpoints
    9. secrets              → Secrets Manager with auto-rotation
   10. rbac-authorization   → Tag-based access control policies
   11. certificates         → mTLS certificates and internal PKI

FEATURES
  ✓ Dependency-aware deployment (waits for dependent modules)
  ✓ Automatic terraform init (initializes state)
  ✓ Confirmation prompts to prevent accidental deployment
  ✓ Automatic approval (uses -auto-approve)
  ✓ Detailed logging (/tmp/<module>_apply.log)
  ✓ Module status checking
  ✓ Error handling with informative messages

EXAMPLE USAGE

  1. Deploy all modules:
     $ ./scripts/deploy.sh

     Deployment Plan
     Modules will be deployed in this order:
       1. vpc (status: NOT_DEPLOYED)
       2. security (status: NOT_DEPLOYED)
       3. bootstrap (status: NOT_DEPLOYED)
       ... (all 11 modules)

     Do you want to proceed? (yes/no): yes

     ✓ Deploying: vpc
     ✓ vpc deployed
     ✓ Deploying: security
     ✓ security deployed
     ... (continues through all modules)

     ✓ All modules deployed successfully
     
     AWS Resources:
       VPC: vpc-12345678
       EC2: i-987654321

  2. Dry run (see what would happen):
     $ ./scripts/deploy.sh --dry-run
     (Shows plan output without making changes)

  3. Deploy only one module:
     $ ./scripts/deploy.sh --module=secrets
     (Useful if one module failed or needs updating)

OPTIONS
  --dry-run           → Show what would be deployed without making changes
  --module=NAME       → Deploy only specific module (no confirmation)
  --destroy           → Destroy instead of deploy (see destroy script)

TROUBLESHOOTING

  "Module deployment failed"
    Check logs: cat /tmp/<module>_apply.log
    Common issues:
      - AWS credentials expired
      - Region not available in your account
      - Insufficient IAM permissions
      - Required secrets not set (db_password, api_key_1, api_key_2)

  "Initialization failed"
    Try manually initializing:
      terraform -chdir=envs/dev/<module> init

  "Plan shows no changes"
    This is normal if resources already exist
    The deployment will be idempotent (safe to re-run)

TIME ESTIMATES
  Full deployment:        10-20 minutes
  Individual module:      1-5 minutes
  Dry run:               1-2 minutes

ENVIRONMENT VARIABLES
  TF_LOG=DEBUG           → Enable Terraform debug logging
  TF_LOG_PATH=tf.log     → Write logs to file
  AWS_PROFILE=myprofile  → Use specific AWS profile


═══════════════════════════════════════════════════════════════════════════════
  DESTROY SCRIPT: ./scripts/destroy.sh
═══════════════════════════════════════════════════════════════════════════════

PURPOSE
  Safely destroys all ZTNA infrastructure with multiple confirmation steps.
  Reverses deployment order to handle dependencies correctly.

USAGE
  ./scripts/destroy.sh                   → Destroy all modules (with confirmation)
  ./scripts/destroy.sh --force           → Destroy without confirmation

DESTRUCTION ORDER
  Modules are destroyed in reverse deployment order:

  Phase 3 - Security (destroyed first)
    1. certificates
    2. rbac-authorization
    3. secrets
    4. vpc-endpoints

  Phase 2 - Core Services
    5. monitoring
    6. data_store
    7. compute
    8. firewall

  Phase 1 - Foundation (destroyed last)
    9. bootstrap
   10. security
   11. vpc

FEATURES
  ✓ Multiple confirmation steps (prevents accidental deletion)
  ✓ Shows what will be destroyed before proceeding
  ✓ Reverse deployment order (handles dependencies)
  ✓ Automatic cleanup of terraform state files
  ✓ Removes .terraform directories
  ✓ Removes lock files
  ✓ Detailed logging (/tmp/<module>_destroy.log)

WHAT GETS DELETED
  ⚠️  WARNING: This will PERMANENTLY DELETE:
    - All VPCs and subnets
    - All EC2 instances
    - All DynamoDB tables
    - All S3 buckets and their contents
    - All KMS keys
    - All IAM roles and policies
    - All Secrets Manager secrets
    - All VPC Endpoints
    - All certificates
    - All CloudTrail logs
    - All CloudWatch resources

EXAMPLE USAGE

  1. Destroy with confirmation (recommended):
     $ ./scripts/destroy.sh

     ⚠️  WARNING: This will PERMANENTLY DELETE all AWS resources!

     Destruction Plan
     Modules will be destroyed in this order:
       1. certificates (will destroy)
       2. rbac-authorization (will destroy)
       3. secrets (will destroy)
       ... (all modules)

     Resources to be destroyed:
       - VPC and all subnets
       - EC2 instances (Bastion and App servers)
       - DynamoDB table
       - S3 buckets and contents
       ... (full list)

     ⚠  This action CANNOT be undone!

     Type 'yes' to confirm destruction: yes

     Type the AWS account ID (123456789) to confirm: 123456789

     ✓ Destroying: certificates
     ✓ certificates destroyed
     ... (continues)

     ✓ All 11 module(s) destroyed successfully
     ✓ ZTNA infrastructure has been completely removed

  2. Destroy without confirmation (dangerous!):
     $ ./scripts/destroy.sh --force
     (Skips all confirmation prompts)

SAFETY FEATURES
  1. Requires typing 'yes' to confirm
  2. Requires entering AWS account ID to confirm
  3. Shows detailed list of what will be deleted
  4. Only used when explicitly requested
  5. Cannot be accidentally triggered by build/deploy

AFTER DESTRUCTION
  ✓ All terraform state files removed
  ✓ All .terraform directories removed
  ✓ All lock files removed
  ✓ Clean slate for next deployment
  ✓ Can re-deploy using: ./scripts/deploy.sh

TIME ESTIMATES
  Full destruction:       5-10 minutes
  Cleanup:               1 minute


═══════════════════════════════════════════════════════════════════════════════
  ADVANCED USAGE
═══════════════════════════════════════════════════════════════════════════════

MANUAL INTERVENTION

  If a specific module fails, fix it manually:
    1. cd envs/dev/<failed_module>
    2. terraform plan    (see what's wrong)
    3. Fix the issue
    4. terraform apply   (retry)
    5. Or run: ./scripts/deploy.sh --module=<name>

CHECKING TERRAFORM STATE

  List all deployed modules:
    $ find envs/dev -name terraform.tfstate -type f

  Check specific module state:
    $ terraform -chdir=envs/dev/<module> state list

  Show outputs from module:
    $ terraform -chdir=envs/dev/<module> output

DEBUGGING DEPLOYMENTS

  Enable debug logging:
    $ TF_LOG=DEBUG ./scripts/deploy.sh 2>&1 | tee deployment.log

  View detailed apply log:
    $ cat /tmp/<module>_apply.log

  View destroy log:
    $ cat /tmp/<module>_destroy.log

PARTIAL DEPLOYMENTS

  Deploy only security layer:
    $ ./scripts/deploy.sh --module=vpc
    $ ./scripts/deploy.sh --module=security
    $ ./scripts/deploy.sh --module=bootstrap

  Deploy only compute:
    $ ./scripts/deploy.sh --module=firewall
    $ ./scripts/deploy.sh --module=compute
    $ ./scripts/deploy.sh --module=data_store

  Deploy only security enhancements:
    $ ./scripts/deploy.sh --module=vpc-endpoints
    $ ./scripts/deploy.sh --module=secrets
    $ ./scripts/deploy.sh --module=rbac-authorization
    $ ./scripts/deploy.sh --module=certificates

CHECKING DEPLOYMENT STATUS

  See what's deployed:
    $ aws ec2 describe-vpcs
    $ aws ec2 describe-instances
    $ aws dynamodb list-tables
    $ aws secretsmanager list-secrets

  Check infrastructure costs:
    $ aws ce get-cost-and-usage --time-period Start=2025-12-01,End=2025-12-31


═══════════════════════════════════════════════════════════════════════════════
  TYPICAL WORKFLOWS
═══════════════════════════════════════════════════════════════════════════════

WORKFLOW 1: First Time Deployment

  1. Clone/download the project
  2. Configure AWS credentials:
     $ aws configure
  3. Build and validate:
     $ ./scripts/build.sh
  4. Review the build output (look for warnings)
  5. Deploy:
     $ ./scripts/deploy.sh
  6. Wait 10-20 minutes
  7. Verify deployment:
     $ aws ec2 describe-instances
  8. Test infrastructure (SSH into Bastion, etc)

WORKFLOW 2: Update Module and Redeploy

  1. Edit module code:
     $ vim modules/vpc/vpc.tf
  2. Build and validate:
     $ ./scripts/build.sh
  3. Review changes:
     $ terraform show terraform-plans/vpc.tfplan
  4. Deploy specific module:
     $ ./scripts/deploy.sh --module=vpc
  5. Verify:
     $ aws ec2 describe-vpcs

WORKFLOW 3: Destroy and Rebuild

  1. Destroy existing infrastructure:
     $ ./scripts/destroy.sh
  2. Confirm destruction
  3. Wait 5-10 minutes
  4. Verify destruction:
     $ aws ec2 describe-instances
  5. Deploy fresh:
     $ ./scripts/deploy.sh

WORKFLOW 4: Dry Run Testing

  1. Test deployment without changes:
     $ ./scripts/deploy.sh --dry-run
  2. Review output
  3. Check for errors
  4. Fix any issues
  5. Run real deployment:
     $ ./scripts/deploy.sh


═══════════════════════════════════════════════════════════════════════════════
  TROUBLESHOOTING & FAQ
═══════════════════════════════════════════════════════════════════════════════

Q: What if deployment fails halfway through?
A: Run deploy.sh again. Terraform is idempotent - it will continue from where
   it failed. If a specific module fails, fix it and run:
   ./scripts/deploy.sh --module=<name>

Q: How do I know what resources were created?
A: Check the terraform state files:
   $ terraform -chdir=envs/dev/vpc state list
   $ terraform -chdir=envs/dev/vpc output

Q: Can I deploy only some modules?
A: Yes, use the --module flag:
   $ ./scripts/deploy.sh --module=vpc
   $ ./scripts/deploy.sh --module=compute
   But note: dependent modules may fail if dependencies aren't deployed

Q: How do I update secrets in Secrets Manager?
A: Modify envs/dev/secrets/terraform.tfvars and run:
   $ ./scripts/deploy.sh --module=secrets

Q: What if I accidentally run destroy?
A: You have two confirmation steps to prevent this:
   1. Type 'yes' to confirm
   2. Type your AWS account ID to confirm
   If you accidentally confirmed, restore from backup or re-deploy.

Q: How do I check deployment progress?
A: While deploying, you can check:
   $ tail -f /tmp/<module>_apply.log

Q: Can I deploy to multiple AWS accounts?
A: Not with these scripts by default. To do so:
   1. Use --profile flag with AWS CLI setup
   2. Or set AWS_PROFILE environment variable before running scripts

Q: How long does deployment take?
A: Typically 10-20 minutes for full deployment (depends on module complexity)
   Individual modules: 1-5 minutes each

Q: Can I cancel a deployment?
A: During confirmation prompts: type 'no'
   During actual deployment: Press Ctrl+C (will interrupt, may leave partial state)

Q: How do I see what changed between deployments?
A: View plan files:
   $ terraform show terraform-plans/vpc.tfplan

Q: Do I need to fix wildcard (*) policies before deploying?
A: YES! See WILDCARD_REMEDIATION.md for details
   ./scripts/build.sh warns about wildcard issues


═══════════════════════════════════════════════════════════════════════════════
  PREREQUISITES & SETUP
═══════════════════════════════════════════════════════════════════════════════

BEFORE RUNNING SCRIPTS

1. Install Terraform
   Download: https://www.terraform.io/downloads.html
   Verify: terraform version

2. Install AWS CLI
   Download: https://aws.amazon.com/cli/
   Verify: aws --version

3. Configure AWS credentials
   $ aws configure
   Enter: Access Key ID, Secret Access Key, Region, Output format

4. Test AWS access
   $ aws sts get-caller-identity
   Should show your AWS account and user info

5. Set secrets (for Secrets Manager module)
   Edit: envs/dev/secrets/terraform.tfvars
   Set: db_password, api_key_1, api_key_2

6. Make scripts executable
   $ chmod +x scripts/build.sh
   $ chmod +x scripts/deploy.sh
   $ chmod +x scripts/destroy.sh

REQUIRED PERMISSIONS

  Your AWS user needs these permissions:
  - EC2: CreateInstances, CreateSecurityGroups, CreateVpc
  - DynamoDB: CreateTable
  - S3: CreateBucket, PutObject
  - KMS: CreateKey, CreateGrant
  - IAM: CreateRole, PutRolePolicy, CreateInstanceProfile
  - SecretsManager: CreateSecret
  - CloudTrail: StartLogging, CreateTrail
  - And many more...

  Easier: Attach AdministratorAccess policy (development only!)
  Production: Use principle of least privilege


═══════════════════════════════════════════════════════════════════════════════
  FILE LOCATIONS
═══════════════════════════════════════════════════════════════════════════════

PROJECT STRUCTURE

Zero_Trust_AWS/
├── scripts/                    ← You are here
│   ├── build.sh              ← Validate and prepare
│   ├── deploy.sh             ← Deploy infrastructure
│   └── destroy.sh            ← Destroy infrastructure
├── modules/                   ← Terraform modules (11 modules)
│   ├── vpc/
│   ├── security/
│   ├── bootstrap/
│   ├── compute/
│   ├── data_store/
│   ├── firewall/
│   ├── monitoring/
│   ├── vpc-endpoints/
│   ├── secrets/
│   ├── rbac-authorization/
│   └── certificates/
├── envs/dev/                  ← Deployment configurations
│   ├── vpc/                  ← Links vpc module
│   ├── security/             ← Links security module
│   ├── bootstrap/            ← Links bootstrap module
│   ... (one per module)
└── terraform-plans/           ← Created by build.sh
    ├── vpc.tfplan
    ├── security.tfplan
    ... (one per module)

STATE FILES LOCATION

After deployment, Terraform state files are created:
  envs/dev/<module>/terraform.tfstate
  envs/dev/<module>/terraform.tfstate.backup

LOG FILES LOCATION

Deployment/destruction logs:
  /tmp/<module>_apply.log
  /tmp/<module>_destroy.log


═══════════════════════════════════════════════════════════════════════════════
  SUPPORT & DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════════

INCLUDED DOCUMENTATION

  00_START_HERE.md              ← Start here
  FINAL_STATUS_REPORT.md        ← Project overview
  DEPLOYMENT_GUIDE.md           ← Detailed deployment steps
  WILDCARD_REMEDIATION.md       ← Security policy fixes needed
  ZTNA_COMPLETENESS_CHECKLIST.md ← What's implemented
  ARCHITECTURE_DIAGRAMS.md       ← Architecture overview

TERRAFORM DOCUMENTATION

  Official: https://www.terraform.io/docs
  AWS Provider: https://registry.terraform.io/providers/hashicorp/aws

GETTING HELP

  1. Check included documentation
  2. Review script output messages
  3. Check /tmp/<module>_apply.log for error details
  4. Run with TF_LOG=DEBUG for detailed debugging
  5. Review Terraform documentation


═══════════════════════════════════════════════════════════════════════════════
  QUICK COMMAND REFERENCE
═══════════════════════════════════════════════════════════════════════════════

BUILDING
  ./scripts/build.sh                          Build and validate

DEPLOYING
  ./scripts/deploy.sh                         Deploy all
  ./scripts/deploy.sh --dry-run               Dry run (no changes)
  ./scripts/deploy.sh --module=vpc            Deploy one module

DESTROYING
  ./scripts/destroy.sh                        Destroy all (with confirmation)
  ./scripts/destroy.sh --force                Destroy without confirmation

CHECKING STATUS
  aws ec2 describe-instances                  List EC2 instances
  aws dynamodb list-tables                    List DynamoDB tables
  aws secretsmanager list-secrets             List secrets
  aws ec2 describe-vpcs                       List VPCs

DEBUGGING
  TF_LOG=DEBUG ./scripts/deploy.sh            Debug logging
  tail -f /tmp/<module>_apply.log             Watch logs during deploy
  terraform show terraform-plans/vpc.tfplan   View plan details


═══════════════════════════════════════════════════════════════════════════════

END OF DOCUMENTATION

For the latest documentation, see: 00_START_HERE.md

Generated: 2025-12-15
Version: 1.0

EOF

