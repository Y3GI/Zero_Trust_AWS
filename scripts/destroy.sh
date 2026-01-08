#!/bin/bash

################################################################################
# ZTNA Destroy Script
# Purpose: Safely destroy all ZTNA infrastructure with confirmation
# Usage: ./scripts/destroy.sh [--force]
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

# Variables
FORCE=false
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        --auto-approve) AUTO_APPROVE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Destruction order (reverse of deployment)
DESTROY_ORDER=(
    "certificates"
    "rbac-authorization"
    "secrets"
    "vpc-endpoints"
    "monitoring"
    "data_store"
    "compute"
    "firewall"
    "bootstrap"
    "security"
    "vpc"
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

# Function to destroy a module
destroy_module() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module"
        return 0
    fi
    
    # Check if terraform is initialized
    if [[ ! -d "$module_path/.terraform" ]]; then
        print_info "$module not deployed, skipping"
        return 0
    fi
    
    print_info "Destroying: $module"
    
    # Destroy the configuration
    if terraform -chdir="$module_path" destroy -auto-approve -no-color > /tmp/${module}_destroy.log 2>&1; then
        print_success "$module destroyed"
        
        # Clear sensitive variables
        if [[ "$module" == "secrets" ]]; then
            unset TF_VAR_db_password
            unset TF_VAR_api_key_1
            unset TF_VAR_api_key_2
        fi
        
        return 0
    else
        print_error "$module destruction failed"
        print_error "Error details:"
        cat /tmp/${module}_destroy.log
        
        # Clear sensitive variables on failure
        if [[ "$module" == "secrets" ]]; then
            unset TF_VAR_db_password
            unset TF_VAR_api_key_1
            unset TF_VAR_api_key_2
        fi
        
        return 1
    fi
}

# Function to get module status
get_module_status() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    if [[ ! -d "$module_path" ]]; then
        echo "NOT_FOUND"
        return
    fi
    
    # Initialize terraform to read remote state (suppress output but show errors)
    if [[ ! -d "$module_path/.terraform" ]]; then
        print_info "Initializing $module to check status..."
        if ! terraform -chdir="$module_path" init -no-color > /tmp/${module}_init.log 2>&1; then
            print_warning "$module initialization failed, checking log..."
            cat /tmp/${module}_init.log | head -20
            echo "NOT_DEPLOYED"
            return
        fi
    fi
    
    # Check if state has any resources by checking state list output
    local state_list=$(terraform -chdir="$module_path" state list 2>&1 | tr '\n' ' ')
    local resource_count=$(echo "$state_list" | grep -o "[a-z_]*\." | wc -l)
    
    if [[ $resource_count -gt 0 ]]; then
        echo "DEPLOYED"
    else
        echo "NOT_DEPLOYED"
    fi
}

print_header "ZTNA Infrastructure Destruction Script"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi
print_success "Terraform ready"

# Check for AWS credentials (from OIDC or aws configure)
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured"
    echo "For GitHub Actions: Ensure OIDC role is configured"
    echo "For local: Run 'aws configure' to set up credentials"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "AWS credentials ready (Account: $ACCOUNT_ID)"

echo ""

# Show destruction plan
print_header "Destruction Plan"
echo "⚠️  WARNING: This will PERMANENTLY DELETE all AWS resources!"
echo ""
echo "Modules will be destroyed in this order:"
deployed_count=0
for i in "${!DESTROY_ORDER[@]}"; do
    module="${DESTROY_ORDER[$i]}"
    status=$(get_module_status "$module")
    if [[ "$status" == "DEPLOYED" ]]; then
        echo "  $((i+1)). $module (will destroy)"
        deployed_count=$((deployed_count + 1))
    else
        echo "  $((i+1)). $module (not deployed)"
    fi
done

echo ""
if [[ $deployed_count -eq 0 ]]; then
    print_info "No modules are currently deployed"
    exit 0
fi

echo "Resources to be destroyed:"
echo "  - VPC and all subnets"
echo "  - EC2 instances (Bastion and App servers)"
echo "  - DynamoDB table"
echo "  - S3 buckets and contents"
echo "  - Network Firewall"
echo "  - KMS keys"
echo "  - IAM roles and policies"
echo "  - Secrets Manager secrets"
echo "  - VPC Endpoints"
echo "  - Certificates"
echo "  - CloudTrail logs"
echo ""
print_warning "This action CANNOT be undone!"
echo ""

# Confirmation
if [[ "$FORCE" == true ]] || [[ "$AUTO_APPROVE" == true ]]; then
    if [[ "$FORCE" == true ]]; then
        print_warning "Using --force flag. Proceeding without confirmation."
    else
        print_info "Auto-approve enabled, proceeding without confirmation"
    fi
else
    # Double confirmation
    read -p "Type 'yes' to confirm destruction: " -r
    echo ""
    if [[ ! $REPLY == "yes" ]]; then
        print_warning "Destruction cancelled"
        exit 0
    fi
    
    # Second confirmation - account ID
    read -p "Type the AWS account ID ($ACCOUNT_ID) to confirm: " -r
    echo ""
    if [[ ! $REPLY == "$ACCOUNT_ID" ]]; then
        print_error "Account ID mismatch. Destruction cancelled."
        exit 1
    fi
fi

echo ""
print_header "Starting Destruction Process"

# Destroy all modules
failed_modules=()
destroyed_count=0

for module in "${DESTROY_ORDER[@]}"; do
    status=$(get_module_status "$module")
    if [[ "$status" == "DEPLOYED" ]]; then
        if destroy_module "$module"; then
            destroyed_count=$((destroyed_count + 1))
        else
            failed_modules+=("$module")
        fi
        echo ""
    fi
done

# Summary
print_header "Destruction Summary"

if [[ ${#failed_modules[@]} -eq 0 ]]; then
    print_success "All $destroyed_count module(s) destroyed successfully"
    print_success "ZTNA infrastructure has been completely removed"
else
    print_error "Failed to destroy ${#failed_modules[@]} module(s): ${failed_modules[*]}"
    print_warning "You may need to manually remove remaining resources"
    echo ""
    echo "Failed modules:"
    for module in "${failed_modules[@]}"; do
        echo "  - $module"
    done
    exit 1
fi

# Cleanup
print_header "Cleanup"
print_info "Cleaning up temporary files..."

# Remove terraform state files
find "$ENVS_DEV_DIR" -name "terraform.tfstate*" -delete
print_success "Removed terraform state files"

# Remove .terraform directories
find "$ENVS_DEV_DIR" -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
print_success "Removed .terraform directories"

# Remove .terraform.lock.hcl files
find "$ENVS_DEV_DIR" -name ".terraform.lock.hcl" -delete
print_success "Removed .terraform.lock files"

echo ""
print_success "Destruction completed successfully!"
print_info "You can now deploy again using: ./scripts/deploy.sh"
echo ""

