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

# Destruction order (reverse of deployment, bootstrap protected)
DESTROY_ORDER=(
    "certificates"
    "rbac-authorization"
    "secrets"
    "vpc-endpoints"
    "monitoring"
    "compute"
    "firewall"
    "vpc"
    "data_store"
    "security"
    "bootstrap"
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
    
    # IMPORTANT: Protect bootstrap from destruction to preserve S3 state bucket
    if [[ "$module" == "bootstrap" ]]; then
        print_warning "PROTECTED: $module NOT destroyed (contains critical S3 state bucket)"
        print_warning "To destroy bootstrap manually, remove the S3 bucket first"
        return 0
    fi
    
    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module"
        return 0
    fi
    
    print_info "Destroying: $module"
    
    # Set up backend configuration from S3
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    # Check if state exists in S3
    if ! aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        print_info "$module state not found in S3, skipping"
        return 0
    fi
    
    # Check if S3 bucket exists and configure backend without DynamoDB
    if aws s3 ls "s3://${STATE_BUCKET}" --region eu-north-1 > /dev/null 2>&1; then
        print_info "Configuring $module backend from S3..."
        
        # Create backend config without DynamoDB (only S3)
        cat > "$module_path/backend-config.hcl" << EOF
bucket         = "${STATE_BUCKET}"
key            = "${STATE_KEY}"
region         = "eu-north-1"
encrypt        = true
EOF
        
        # Initialize/reconfigure terraform with S3 backend
        print_info "Initializing $module from S3 state..."
        if ! terraform -chdir="$module_path" init -reconfigure -backend-config=backend-config.hcl -no-color -input=false > /tmp/${module}_init.log 2>&1; then
            print_warning "$module initialization from S3 had issues (may still proceed):"
            head -5 /tmp/${module}_init.log
        fi
    else
        print_warning "S3 state bucket not found, cannot configure backend"
        return 0
    fi
    
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

# Function to force delete ACM PCA instances (VERY expensive - ~$400/month each)
cleanup_acm_pca() {
    print_info "Checking for active ACM PCA instances (expensive - ~\$400/month each)..."
    
    # Get all non-deleted ACM PCA instances
    ACTIVE_CAS=$(aws acm-pca list-certificate-authorities \
        --region eu-north-1 \
        --query "CertificateAuthorities[?Status!='DELETED'].Arn" \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$ACTIVE_CAS" ]]; then
        print_info "No active ACM PCA instances found"
        return 0
    fi
    
    ca_count=$(echo "$ACTIVE_CAS" | wc -w)
    estimated_cost=$(echo "$ca_count * 93" | bc)  # ~$400/month / 30 days * 7 days = ~$93 per CA
    
    print_warning "Found $ca_count active ACM PCA instance(s) - scheduling for deletion!"
    print_warning "⚠️  IMPORTANT: AWS requires a 7-day waiting period for ACM PCA deletion"
    print_warning "💰 Estimated additional cost: ~\$$estimated_cost (\$400/month × 7 days / 30)"
    print_warning "After 7 days: deletion complete, no more charges"
    echo ""
    for ca_arn in $ACTIVE_CAS; do
        echo "  - $ca_arn"
    done
    echo ""
    
    # Delete each CA
    for ca_arn in $ACTIVE_CAS; do
        print_info "Disabling ACM PCA: $ca_arn"
        
        # First, disable the CA (needed before deletion)
        aws acm-pca update-certificate-authority \
            --certificate-authority-arn "$ca_arn" \
            --status DISABLED \
            --region eu-north-1 2>/dev/null || true
        
        # Wait a moment for the status change
        sleep 1
        
        # Delete the CA with 7-day permanent deletion time (AWS minimum)
        print_info "Scheduling deletion with 7-day wait (AWS minimum): $ca_arn"
        if aws acm-pca delete-certificate-authority \
            --certificate-authority-arn "$ca_arn" \
            --permanent-deletion-time-in-days 7 \
            --region eu-north-1 2>/dev/null; then
            print_success "ACM PCA disabled and scheduled for deletion: $ca_arn"
        else
            print_warning "Could not delete ACM PCA (may already be scheduled): $ca_arn"
        fi
    done
    
    echo ""
    print_warning "🕐 ACM PCA deletion timeline:"
    print_warning "  - NOW: Disabled (stops new charges, but still exists in AWS)"
    print_warning "  - Days 1-7: Pending deletion (AWS may still bill during this period)"
    print_warning "  - Day 7+: Permanently deleted (no more charges)"
    print_warning "  - Total cost: ~\$$estimated_cost for this deletion window"
    
    return 0
}

# Function to get module status from S3 state (not local)
get_module_status() {
    local module=$1
    
    # Skip bootstrap - always check local status for it
    if [[ "$module" == "bootstrap" ]]; then
        local module_path="$ENVS_DEV_DIR/$module"
        if [[ -d "$module_path/.terraform" ]]; then
            echo "DEPLOYED"
        else
            echo "NOT_DEPLOYED"
        fi
        return
    fi
    
    # For other modules, check S3 state
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    STATE_BUCKET="dev-terraform-state-${ACCOUNT_ID}"
    STATE_KEY="dev/${module}/terraform.tfstate"
    
    # Check if state file exists in S3
    if aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" --region eu-north-1 > /dev/null 2>&1; then
        # State file exists - check if it has resources
        # Read the state file and check for resources
        if aws s3api get-object --bucket "${STATE_BUCKET}" --key "${STATE_KEY}" /tmp/${module}_state.json --region eu-north-1 > /dev/null 2>&1; then
            # Check if state has any resources
            if grep -q '"type":' /tmp/${module}_state.json 2>/dev/null; then
                echo "DEPLOYED"
            else
                echo "NOT_DEPLOYED"
            fi
            rm -f /tmp/${module}_state.json
        else
            echo "NOT_DEPLOYED"
        fi
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

# First, clean up expensive ACM PCA instances
echo ""
cleanup_acm_pca
echo ""

# Destroy all modules
failed_modules=()
destroyed_count=0

for module in "${DESTROY_ORDER[@]}"; do
    destroy_module "$module"
    echo ""
done

# Summary
print_header "Destruction Summary"
print_success "Destruction completed successfully!"
print_success "ZTNA infrastructure has been removed"

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
print_info "You can now deploy again using: ./scripts/deploy.sh"
echo ""

