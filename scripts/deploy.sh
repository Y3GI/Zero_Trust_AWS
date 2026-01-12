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

# Function to find the actual terraform state bucket name
# Buckets may have random suffixes like dev-terraform-state-abc123
find_state_bucket() {
    local region="eu-north-1"
    
    # List all buckets and find one matching dev-terraform-state-*
    local bucket_name
    bucket_name=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'dev-terraform-state-')].Name" --output text 2>/dev/null | head -1)
    
    if [[ -n "$bucket_name" && "$bucket_name" != "None" ]]; then
        echo "$bucket_name"
        return 0
    fi
    
    return 1
}

# Global variable to cache the state bucket name (avoid repeated API calls)
CACHED_STATE_BUCKET=""

# Function to get the state bucket name (uses cache)
get_state_bucket() {
    if [[ -z "$CACHED_STATE_BUCKET" ]]; then
        CACHED_STATE_BUCKET=$(find_state_bucket)
    fi
    echo "$CACHED_STATE_BUCKET"
}

# Function to check and configure S3 backend if available
# Falls back to local backend if S3 doesn't exist (recovery scenario)
configure_backend() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Skip bootstrap (it uses local backend and uploads to S3 manually after)
    if [[ "$module" == "bootstrap" ]]; then
        return 0
    fi
    
    # Find the actual S3 state bucket (may have random suffix)
    STATE_BUCKET=$(get_state_bucket)
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
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
        
        # Check if we have local state that should be migrated to S3
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            # Check if S3 already has this state
            if ! aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
                print_info "Local state found for $module - will migrate to S3 after init"
            fi
        fi
        
        # Reconfigure if already initialized
        if [[ -d "$module_path/.terraform" ]]; then
            print_info "Reconfiguring $module backend to use S3..."
            terraform -chdir="$module_path" init -reconfigure -backend-config=backend-config.hcl -no-color > /tmp/${module}_init.log 2>&1 || true
        fi
    else
        # S3 bucket doesn't exist - use local backend
        if [[ -n "$STATE_BUCKET" ]]; then
            print_warning "S3 state bucket not accessible (${STATE_BUCKET})"
        else
            print_warning "No S3 state bucket found"
        fi
        
        # Check if we have local state to use
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            print_info "Using existing local state for $module (will upload to S3 when available)"
        else
            print_info "No local state found - will deploy $module fresh"
        fi
        
        # Remove any S3 backend config to force local backend
        rm -f "$module_path/backend-config.hcl"
        
        # If .terraform exists with S3 backend, clear it to use local
        if [[ -d "$module_path/.terraform" ]]; then
            # Check if current backend is S3
            if grep -q "s3" "$module_path/.terraform/terraform.tfstate" 2>/dev/null; then
                print_info "Clearing S3 backend config for $module (switching to local)"
                rm -rf "$module_path/.terraform"
            fi
        fi
    fi
    
    return 0
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

################################################################################
# UNIFIED DEPLOYMENT FLOW - Used by ALL modules (including bootstrap)
# 
# Flow:
# 1. Init module
# 2. Create local plan (based on current Terraform config)
# 3. Fetch cloud state (from S3 or local for bootstrap)
# 4. Compare: Does local plan want to make changes?
# 5. If changes needed: apply them, then upload new state to S3
# 6. If no changes: skip deployment
#
# Recovery scenarios:
# - No S3 state: Use local state if exists, deploy fresh if not
# - S3 bucket deleted: Bootstrap recreates it, then upload local states
################################################################################

# Function to check if local state exists for a module
has_local_state() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Check for local terraform.tfstate file
    if [[ -f "$module_path/terraform.tfstate" ]]; then
        # Verify it has actual resources
        if grep -q '"type":' "$module_path/terraform.tfstate" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Check for .terraform/terraform.tfstate (cached backend state)
    if [[ -f "$module_path/.terraform/terraform.tfstate" ]]; then
        return 0
    fi
    
    return 1
}

# Function to get cloud state for a module
# Returns: 0 if state exists (cloud or local), 1 if no state (fresh deployment)
fetch_cloud_state() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Find actual state bucket (may have random suffix)
    STATE_BUCKET=$(get_state_bucket)
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    # Bootstrap uses local backend but may have state in S3
    if [[ "$module" == "bootstrap" ]]; then
        # Check local state first (priority for bootstrap)
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            cp "$module_path/terraform.tfstate" /tmp/${module}_cloud_state.json
            print_info "Using local state for $module"
            return 0
        fi
        # Check S3 as backup (only if bucket exists)
        if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
            if aws s3 cp "s3://${STATE_BUCKET}/${STATE_KEY}" /tmp/${module}_cloud_state.json --region eu-north-1 > /dev/null 2>&1; then
                # Also restore to local for bootstrap
                cp /tmp/${module}_cloud_state.json "$module_path/terraform.tfstate"
                print_info "Restored $module state from S3 to local"
                return 0
            fi
        fi
        return 1  # No state exists
    fi
    
    # Other modules: Try S3 first (if bucket exists), then fall back to local
    if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        if aws s3 cp "s3://${STATE_BUCKET}/${STATE_KEY}" /tmp/${module}_cloud_state.json --region eu-north-1 > /dev/null 2>&1; then
            print_info "Using S3 state for $module (bucket: $STATE_BUCKET)"
            return 0
        fi
    fi
    
    # S3 state not found - check for local state (recovery scenario)
    if [[ -f "$module_path/terraform.tfstate" ]]; then
        cp "$module_path/terraform.tfstate" /tmp/${module}_cloud_state.json
        print_warning "S3 state not found for $module - using local state (will upload to S3 after deploy)"
        return 0
    fi
    
    return 1  # No state exists anywhere
}

# Function to upload state to S3 after deployment
# Handles: bootstrap local->S3, other modules local->S3 recovery
upload_state_to_s3() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Find actual state bucket (may have random suffix)
    # Re-discover after bootstrap in case it just created the bucket
    CACHED_STATE_BUCKET=""  # Clear cache to re-discover
    STATE_BUCKET=$(get_state_bucket)
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    # Check if S3 bucket exists
    if [[ -z "$STATE_BUCKET" ]] || ! aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
        # Bucket doesn't exist yet (bootstrap hasn't created it or was deleted)
        if [[ "$module" == "bootstrap" ]]; then
            print_info "S3 bucket will be available after bootstrap completes"
        else
            print_warning "S3 state bucket doesn't exist yet - state stored locally only"
            # Save local state for later upload
            if [[ -f "$module_path/.terraform/terraform.tfstate" ]]; then
                # Extract state from backend cache if available
                print_info "Preserving local state for $module"
            fi
        fi
        return 0
    fi
    
    print_info "Uploading state to S3 bucket: $STATE_BUCKET"
    
    # For bootstrap, upload local state to S3
    if [[ "$module" == "bootstrap" ]]; then
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            # Delete old state first (clean replace)
            aws s3 rm "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1 || true
            
            if aws s3 cp "$module_path/terraform.tfstate" "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 --sse AES256 > /dev/null 2>&1; then
                print_success "$module state uploaded to S3"
            else
                print_warning "Failed to upload $module state to S3"
            fi
        fi
        return 0
    fi
    
    # For other modules using S3 backend - state should already be in S3
    # But check if we need to upload local state (recovery from deleted S3)
    if ! aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        # State not in S3 - try to upload local state
        if [[ -f "$module_path/terraform.tfstate" ]]; then
            print_info "Uploading local state to S3 for $module..."
            if aws s3 cp "$module_path/terraform.tfstate" "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 --sse AES256 > /dev/null 2>&1; then
                print_success "$module local state uploaded to S3"
            else
                print_warning "Failed to upload $module local state to S3"
            fi
        fi
    else
        print_success "$module state synced to S3"
    fi
    
    return 0
}

# Helper function to upload state to S3 after fresh deployment
upload_new_state_to_s3() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Clear cache to re-discover bucket (bootstrap may have just created it)
    CACHED_STATE_BUCKET=""
    STATE_BUCKET=$(get_state_bucket)
    
    if [[ -z "$STATE_BUCKET" ]]; then
        print_warning "No S3 bucket available - state not uploaded"
        return 0
    fi
    
    STATE_KEY="dev/${module}/terraform.tfstate"
    local state_file="$module_path/terraform.tfstate"
    
    # For modules using S3 backend, pull state first
    if [[ -f "$module_path/backend-config.hcl" ]]; then
        terraform -chdir="$module_path" state pull > "$state_file" 2>/dev/null || true
    fi
    
    if [[ -f "$state_file" ]]; then
        print_info "Uploading state to S3 (bucket: $STATE_BUCKET)..."
        aws s3 rm "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1 || true
        if aws s3 cp "$state_file" "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 --sse AES256 > /dev/null 2>&1; then
            print_success "State uploaded to S3"
        else
            print_warning "Failed to upload state to S3"
        fi
    fi
    
    return 0
}

################################################################################
# MAIN DEPLOYMENT FUNCTION
# Optimized for GitHub Actions (no persistent local storage)
#
# Flow:
# 1. Check if state exists in S3
# 2. If NO state → Deploy immediately (fresh deployment)
# 3. If state exists → Download, plan, check for changes
# 4. If changes needed → Deploy and upload new state to S3
# 5. If no changes → Skip (AWS matches config)
################################################################################

# Helper function to get terraform var args for a module
# All modules accept state_bucket variable for consistency
get_terraform_var_args() {
    local bucket=$1
    
    if [[ -n "$bucket" ]]; then
        echo "-var state_bucket=$bucket"
    fi
}

deploy_module() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    local plan_changes=0
    local has_cloud_state=false
    
    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module"
        return 1
    fi
    
    print_info "Deploying: $module"
    
    # Handle monitoring module - check and import existing log group
    if [[ "$module" == "monitoring" ]]; then
        handle_monitoring_log_group
    fi
    
    # =========================================================================
    # Step 1: CLEAN START (GitHub Actions has no persistent storage)
    # =========================================================================
    rm -rf "$module_path/.terraform"
    rm -f "$module_path/backend-config.hcl"
    rm -f "$module_path/terraform.tfstate"
    rm -f "$module_path/terraform.tfstate.backup"
    
    # =========================================================================
    # Step 2: CHECK IF STATE EXISTS IN S3
    # =========================================================================
    STATE_BUCKET=$(get_state_bucket)
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        has_cloud_state=true
        print_info "Found existing state in S3 for $module - downloading..."
        if aws s3 cp "s3://${STATE_BUCKET}/${STATE_KEY}" "$module_path/terraform.tfstate" --region eu-north-1 > /dev/null 2>&1; then
            print_success "State downloaded from S3"
        else
            print_warning "Failed to download state from S3"
            has_cloud_state=false
        fi
    else
        print_info "No state in cloud for $module - will deploy fresh"
    fi
    
    # =========================================================================
    # Step 3: CONFIGURE BACKEND AND INIT
    # =========================================================================
    configure_backend "$module"
    
    if ! init_module "$module"; then
        return 1
    fi
    
    # Get terraform var args (all modules accept state_bucket)
    local var_args=$(get_terraform_var_args "$STATE_BUCKET")
    
    # =========================================================================
    # Step 4: IF NO CLOUD STATE → DEPLOY IMMEDIATELY (skip plan check)
    # =========================================================================
    if [[ "$has_cloud_state" == false ]]; then
        print_info "No cloud state exists - deploying $module..."
        
        # Handle dry-run mode
        if [[ "$DRY_RUN" == true ]]; then
            print_info "Resources that would be created:"
            terraform -chdir="$module_path" plan $var_args -no-color 2>&1 | head -50
            print_success "$module (dry-run completed)"
            return 0
        fi
        
        # Apply directly
        if terraform -chdir="$module_path" apply $var_args -auto-approve -no-color > /tmp/${module}_apply.log 2>&1; then
            resource_count=$(terraform -chdir="$module_path" state list 2>/dev/null | wc -l | tr -d ' ')
            print_success "$module deployed ($resource_count resources)"
            
            # Upload state to S3
            upload_new_state_to_s3 "$module"
            return 0
        else
            print_error "$module deployment failed"
            cat /tmp/${module}_apply.log
            return 1
        fi
    fi
    
    # =========================================================================
    # Step 5: CLOUD STATE EXISTS → Create plan and check for changes
    # =========================================================================
    print_info "Creating terraform plan for $module..."
    if ! terraform -chdir="$module_path" plan $var_args -out=/tmp/${module}_local.tfplan -no-color > /tmp/${module}_plan_output.log 2>&1; then
        print_warning "Plan had issues for $module"
        cat /tmp/${module}_plan_output.log | tail -20
    else
        print_success "Plan created for $module"
    fi
    
    # =========================================================================
    # Step 6: COUNT CHANGES FROM PLAN
    # =========================================================================
    if [[ -f "/tmp/${module}_local.tfplan" ]]; then
        if terraform -chdir="$module_path" show -json /tmp/${module}_local.tfplan > /tmp/${module}_local_plan.json 2>/dev/null; then
            plan_changes=$(jq -r '.resource_changes[]? | select(.change.actions != ["no-op"]) | .address' /tmp/${module}_local_plan.json 2>/dev/null | wc -l | tr -d ' ')
        fi
    fi
    
    # =========================================================================
    # Step 7: DECIDE - Deploy or Skip
    # =========================================================================
    if [[ "$plan_changes" -eq 0 ]]; then
        print_success "$module is up-to-date (0 changes)"
        rm -f /tmp/${module}_local.tfplan /tmp/${module}_local_plan.json
        return 0
    fi
    
    print_info "$module has $plan_changes change(s) to apply"
    
    # Handle dry-run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Changes that would be applied:"
        terraform -chdir="$module_path" plan $var_args -no-color 2>&1 | head -50
        print_success "$module (dry-run completed)"
        rm -f /tmp/${module}_local.tfplan /tmp/${module}_local_plan.json
        return 0
    fi
    
    # =========================================================================
    # Step 8: APPLY CHANGES
    # =========================================================================
    print_info "Applying changes to $module..."
    if terraform -chdir="$module_path" apply $var_args -auto-approve -no-color > /tmp/${module}_apply.log 2>&1; then
        resource_count=$(terraform -chdir="$module_path" state list 2>/dev/null | wc -l | tr -d ' ')
        print_success "$module deployed ($resource_count resources)"
    else
        print_error "$module deployment failed"
        cat /tmp/${module}_apply.log
        rm -f /tmp/${module}_local.tfplan /tmp/${module}_local_plan.json
        return 1
    fi
    
    # =========================================================================
    # Step 9: UPLOAD STATE TO S3
    # =========================================================================
    upload_new_state_to_s3 "$module"
    
    # Cleanup
    rm -f /tmp/${module}_local.tfplan /tmp/${module}_local_plan.json
    
    return 0
}

# Function to get module status from S3 state (not local)
get_module_status() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    # Find actual state bucket (may have random suffix)
    STATE_BUCKET=$(get_state_bucket)
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
        if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
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
    
    # For other modules, check local state first, then S3
    # Check local state
    if [[ -f "$module_path/terraform.tfstate" ]]; then
        if grep -q '"type":' "$module_path/terraform.tfstate" 2>/dev/null; then
            echo "DEPLOYED"
            return
        fi
    fi
    
    # Check S3 state (if bucket exists)
    if [[ -n "$STATE_BUCKET" ]] && aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
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

