#!/bin/bash

################################################################################
# ZTNA Deploy Script
# Purpose: Deploy ZTNA infrastructure to AWS in correct dependency order
# Usage: ./scripts/deploy.sh [--destroy] [--module=MODULE_NAME]
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DEV_DIR="$PROJECT_ROOT/envs/dev"
PLANS_DIR="$PROJECT_ROOT/terraform-plans"

# Variables
TARGET_MODULE=""
DRY_RUN=false
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --auto-approve) AUTO_APPROVE=true; shift ;;
        --module=*) TARGET_MODULE="${1#*=}"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Deployment order (respects dependencies)
DEPLOYMENT_ORDER=(
    "bootstrap"
    "security"
    "data_store"
    "vpc"
    "firewall"
    "compute"
    "monitoring"
    "vpc-endpoints"
    "secrets"
    "rbac-authorization"
    "certificates"
)

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to check and configure S3 backend if available
configure_backend() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Skip bootstrap (it uses local backend and uploads to S3 manually after)
    if [[ "$module" == "bootstrap" ]]; then
        return 0
    fi
    
    # Check if S3 state bucket exists
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    
    if aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
        print_info "S3 state bucket found (${STATE_BUCKET}), configuring S3 backend..."
        
        # Check if DynamoDB locks table exists (created by data_store)
        # If it doesn't exist yet, we'll configure S3 without locking initially
        if aws dynamodb describe-table --table-name "dev-terraform-locks" --region eu-north-1 > /dev/null 2>&1; then
            print_info "DynamoDB locks table found, configuring S3 backend with locking..."
            DYNAMODB_CONFIG="dynamodb_table = \"dev-terraform-locks\""
        else
            print_info "DynamoDB locks table not found yet, configuring S3 backend without locking (will use local locking)"
            DYNAMODB_CONFIG="skip_credentials_validation = false"
        fi
        
        # Create backend config file (with or without DynamoDB)
        cat > "$module_path/backend-config.hcl" << EOF
bucket         = "${STATE_BUCKET}"
key            = "dev/${module}/terraform.tfstate"
region         = "eu-north-1"
encrypt        = true
${DYNAMODB_CONFIG}
EOF
        
        # Reconfigure if already initialized
        if [[ -d "$module_path/.terraform" ]]; then
            print_info "Reconfiguring $module backend to use S3..."
            terraform -chdir="$module_path" init -reconfigure -backend-config=backend-config.hcl -no-color > /tmp/${module}_init.log 2>&1 || true
        fi
    else
        print_info "S3 state bucket not found yet (${STATE_BUCKET}), using local state"
    fi
    
    return 0
}

# Function to migrate bootstrap state from local to S3 (after S3 bucket is created)
migrate_bootstrap_to_s3() {
    local module="bootstrap"
    local module_path="$ENVS_DEV_DIR/$module"
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    
    # Check if S3 bucket exists and bootstrap state exists locally
    if [[ -f "$module_path/terraform.tfstate" ]] && aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
        print_info "Uploading bootstrap state to S3..."
        
        # Upload the local state file to S3
        if aws s3 cp "$module_path/terraform.tfstate" "s3://${STATE_BUCKET}/dev/bootstrap/terraform.tfstate" --region eu-north-1 --sse AES256 > /dev/null 2>&1; then
            print_success "Bootstrap state uploaded to S3"
        else
            print_warning "Failed to upload bootstrap state to S3"
        fi
    fi
}

# Function to initialize a module
init_module() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Check if terraform is already initialized
    if [[ -d "$module_path/.terraform" ]]; then
        return 0
    fi
    
    print_info "Initializing $module..."
    
    # If backend-config exists (from configure_backend), use it
    if [[ -f "$module_path/backend-config.hcl" ]]; then
        if ! terraform -chdir="$module_path" init -backend-config=backend-config.hcl -no-color > /tmp/${module}_init.log 2>&1; then
            print_error "$module initialization failed"
            print_error "Error details:"
            cat /tmp/${module}_init.log
            return 1
        fi
    else
        if ! terraform -chdir="$module_path" init -no-color > /tmp/${module}_init.log 2>&1; then
            print_error "$module initialization failed"
            print_error "Error details:"
            cat /tmp/${module}_init.log
            return 1
        fi
    fi
    print_success "$module initialized"
    return 0
}

# Function to deploy a module
deploy_module() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module"
        return 1
    fi
    
    # Handle monitoring module - check and import existing log group
    if [[ "$module" == "monitoring" ]]; then
        handle_monitoring_log_group
    fi
    
    # Handle bootstrap - import existing S3 buckets if they exist
    if [[ "$module" == "bootstrap" ]]; then
        handle_bootstrap_import
    fi
    
    print_info "Deploying: $module"
    
    # Always clean .terraform to force re-initialization when backend block is present
    if [[ -d "$module_path/.terraform" ]]; then
        rm -rf "$module_path/.terraform"
    fi
    
    # Configure backend if S3 is available (skipped for bootstrap)
    configure_backend "$module"
    
    # Initialize the module with backend config if available
    if ! init_module "$module"; then
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        terraform -chdir="$module_path" plan -no-color 2>&1 | head -50
        print_success "$module (dry-run completed)"
        return 0
    fi
    
    # Apply the configuration (always run, even if already deployed - to handle updates)
    if terraform -chdir="$module_path" apply -auto-approve -no-color > /tmp/${module}_apply.log 2>&1; then
        # Check if this was a create or update
        resource_count=$(terraform -chdir="$module_path" state list 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$resource_count" -gt 0 ]]; then
            print_success "$module deployed/updated (contains $resource_count resources)"
        else
            print_success "$module deployed"
        fi
        return 0
    else
        print_error "$module deployment failed"
        print_error "Error details:"
        cat /tmp/${module}_apply.log
        return 1
    fi
}

# Function to get module status from S3 state (not local)
get_module_status() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    # For bootstrap, also check local state (it uses local backend)
    if [[ "$module" == "bootstrap" ]]; then
        # Check local state first
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            if grep -q '"type":' "$module_path/terraform.tfstate" 2>/dev/null; then
                echo "DEPLOYED"
                return
            fi
        fi
        
        # Also check if state exists in S3 (bootstrap uploads after deploy)
        if aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
            if aws s3api get-object --bucket "${STATE_BUCKET}" --key "${STATE_KEY}" /tmp/bootstrap_state.json --region eu-north-1 > /dev/null 2>&1; then
                if grep -q '"type":' /tmp/bootstrap_state.json 2>/dev/null; then
                    rm -f /tmp/bootstrap_state.json
                    echo "DEPLOYED"
                    return
                fi
                rm -f /tmp/bootstrap_state.json
            fi
        fi
        
        echo "NOT_DEPLOYED"
        return
    fi
    
    # For other modules, check S3 state and actually query with terraform
    if aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        # State file exists in S3
        # Initialize terraform temporarily to check state
        if [[ -d "$module_path" ]]; then
            # Create a temporary backend config
            cat > "$module_path/backend-config.hcl" << EOF
bucket         = "${STATE_BUCKET}"
key            = "${STATE_KEY}"
region         = "eu-north-1"
encrypt        = true
skip_credentials_validation = true
EOF
            
            # Initialize quietly (without .terraform output)
            if terraform -chdir="$module_path" init -reconfigure -backend-config=backend-config.hcl -no-color -input=false > /dev/null 2>&1; then
                # Use terraform to check state list
                if terraform -chdir="$module_path" state list > /dev/null 2>&1; then
                    resource_count=$(terraform -chdir="$module_path" state list 2>/dev/null | wc -l | tr -d ' ')
                    if [[ "$resource_count" -gt 0 ]]; then
                        echo "DEPLOYED"
                        return
                    fi
                fi
            fi
        fi
    fi
    
    echo "NOT_DEPLOYED"
}

# Function to handle bootstrap resource imports (if they already exist in AWS)
handle_bootstrap_import() {
    local module_path="$ENVS_DEV_DIR/bootstrap"
    
    print_info "Checking for existing bootstrap resources in AWS..."
    
    # Check if terraform state bucket already exists
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    
    if aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
        print_info "S3 state bucket already exists: $STATE_BUCKET"
        print_info "Importing existing bootstrap buckets into Terraform state..."
        
        # Initialize first (needed for import)
        if ! terraform -chdir="$module_path" init -no-color > /dev/null 2>&1; then
            print_warning "Could not initialize bootstrap for import"
            return 0
        fi
        
        # Import terraform state bucket
        print_info "Importing: aws_s3_bucket.terraform_state -> $STATE_BUCKET"
        terraform -chdir="$module_path" import -no-color aws_s3_bucket.terraform_state "$STATE_BUCKET" > /dev/null 2>&1 || true
        
        # Import CloudTrail bucket (find it by pattern)
        CLOUDTRAIL_BUCKET=$(aws s3 ls --region eu-north-1 2>/dev/null | grep "dev-ztna-audit-logs" | awk '{print $3}' | head -1)
        if [[ -n "$CLOUDTRAIL_BUCKET" ]]; then
            print_info "Importing: aws_s3_bucket.cloudtrail_bucket -> $CLOUDTRAIL_BUCKET"
            terraform -chdir="$module_path" import -no-color aws_s3_bucket.cloudtrail_bucket "$CLOUDTRAIL_BUCKET" > /dev/null 2>&1 || true
        fi
        
        print_success "Bootstrap buckets imported"
    fi
}

# Function to handle existing CloudWatch log groups
handle_monitoring_log_group() {
    local log_group_name="/aws/vpc/flow-logs/dev"
    local region="eu-north-1"
    local module_path="$ENVS_DEV_DIR/monitoring"
    
    print_info "Checking for existing CloudWatch log group: $log_group_name"
    
    # Check if log group exists in AWS
    if aws logs describe-log-groups \
        --log-group-name-prefix "$log_group_name" \
        --region "$region" 2>/dev/null | grep -q "\"logGroupName\": \"$log_group_name\""; then
        
        print_info "Log group exists in AWS"
        
        # Try to import it silently
        terraform -chdir="$module_path" import -no-color module.monitoring.aws_cloudwatch_log_group.vpc_flow_logs "$log_group_name" > /dev/null 2>&1 || true
        
        # If it's in state and already exists in AWS, that's fine
        if terraform -chdir="$module_path" state list 2>/dev/null | grep -q "module.monitoring.aws_cloudwatch_log_group.vpc_flow_logs"; then
            print_success "Log group already managed by Terraform"
        else
            print_warning "Log group exists in AWS but not in Terraform - will adopt during apply"
        fi
    else
        print_info "Log group does not exist in AWS - will be created during apply"
    fi
}

# Check prerequisites
print_header "ZTNA Infrastructure $([ "$DESTROY" = true ] && echo 'Destruction' || echo 'Deployment') Script"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi
print_success "Terraform ready"

if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "AWS credentials ready (Account: $ACCOUNT_ID)"

echo ""

# Show deployment plan
if [[ "$DESTROY" == true ]]; then
    print_header "Destruction Plan"
    echo "Modules will be destroyed in this order:"
    for i in "${!DESTROY_ORDER[@]}"; do
        module="${DESTROY_ORDER[$i]}"
        status=$(get_module_status "$module")
        if [[ "$status" == "DEPLOYED" ]]; then
            echo "  $((i+1)). $module (will destroy)"
        else
            echo "  $((i+1)). $module (already destroyed)"
        fi
    done
else
    print_header "Deployment Plan"
    echo "Modules will be deployed in this order:"
    for i in "${!DEPLOYMENT_ORDER[@]}"; do
        module="${DEPLOYMENT_ORDER[$i]}"
        status=$(get_module_status "$module")
        echo "  $((i+1)). $module (status: $status)"
    done
fi

echo ""

# Confirmation
if [[ "$DRY_RUN" != true ]] && [[ "$AUTO_APPROVE" != true ]]; then
    read -p "Do you want to proceed? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
elif [[ "$AUTO_APPROVE" == true ]]; then
    print_info "Auto-approve enabled, proceeding without confirmation"
fi

echo ""

# Execute deployment
if [[ -n "$TARGET_MODULE" ]]; then
    # Deploy single module
    print_header "Single Module Deployment: $TARGET_MODULE"
    if ! deploy_module "$TARGET_MODULE"; then
        exit 1
    fi
else
    # Deploy all modules
    print_header "Starting Full Deployment"
        
        failed_modules=()
        for module in "${DEPLOYMENT_ORDER[@]}"; do
            if ! deploy_module "$module"; then
                failed_modules+=("$module")
                print_error "Stopping deployment due to failure in $module"
                break
            fi
            
            # After bootstrap is deployed, migrate it to S3
            if [[ "$module" == "bootstrap" ]]; then
                migrate_bootstrap_to_s3
            fi
            
            echo ""
        done
        
        # Summary
        print_header "Deployment Summary"
        if [[ ${#failed_modules[@]} -eq 0 ]]; then
            print_success "All modules deployed successfully"
            echo ""
            echo "AWS Resources:"
            echo "  VPC: $(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)"
            echo "  EC2: $(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)"
            echo ""
        else
            print_error "Failed to deploy modules: ${failed_modules[*]}"
            exit 1
        fi
fi

echo ""
print_success "Deployment completed!"
echo ""

