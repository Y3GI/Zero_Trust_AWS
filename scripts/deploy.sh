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
DESTROY=false
TARGET_MODULE=""
DRY_RUN=false
AUTO_APPROVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --destroy) DESTROY=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --auto-approve) AUTO_APPROVE=true; shift ;;
        --module=*) TARGET_MODULE="${1#*=}"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Deployment order (respects dependencies)
DEPLOYMENT_ORDER=(
    "vpc"
    "security"
    "bootstrap"
    "firewall"
    "compute"
    "data_store"
    "monitoring"
    "vpc-endpoints"
    "secrets"
    "rbac-authorization"
    "certificates"
)

# Destroy order (reverse of deployment)
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
    
    
    print_info "Deploying: $module"
    
    if [[ "$DRY_RUN" == true ]]; then
        terraform -chdir="$module_path" plan -no-color 2>&1 | head -50
        print_success "$module (dry-run completed)"
        return 0
    fi
    
    # Check if terraform is initialized
    if [[ ! -d "$module_path/.terraform" ]]; then
        print_info "Initializing $module..."
        if ! terraform -chdir="$module_path" init -no-color > /tmp/${module}_init.log 2>&1; then
            print_error "$module initialization failed"
            print_error "Error details:"
            cat /tmp/${module}_init.log
            return 1
        fi
    fi
    
    # Apply the configuration
    if terraform -chdir="$module_path" apply -auto-approve -no-color > /tmp/${module}_apply.log 2>&1; then
        print_success "$module deployed"
        return 0
    else
        print_error "$module deployment failed"
        print_error "Error details:"
        cat /tmp/${module}_apply.log
        return 1
    fi
}

# Function to destroy a module
destroy_module() {
    local module=$1
    local module_path="$ENVS_DEV_DIR/$module"
    
    if [[ ! -d "$module_path" ]]; then
        print_warning "Module directory not found: $module"
        return 1
    fi
    
    print_info "Destroying: $module"
    
    # Check if terraform is initialized
    if [[ ! -d "$module_path/.terraform" ]]; then
        print_warning "$module not deployed, skipping"
        return 0
    fi
    
    # Destroy the configuration
    if terraform -chdir="$module_path" destroy -auto-approve -no-color > /tmp/${module}_destroy.log 2>&1; then
        print_success "$module destroyed"
        return 0
    else
        print_error "$module destruction failed"
        print_info "Check logs: cat /tmp/${module}_destroy.log"
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
    
    if [[ -f "$module_path/terraform.tfstate" ]]; then
        echo "DEPLOYED"
    else
        echo "NOT_DEPLOYED"
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

# Execute deployment or destruction
if [[ "$DESTROY" == true ]]; then
    print_header "Starting Destruction"
    
    failed_modules=()
    for module in "${DESTROY_ORDER[@]}"; do
        if ! destroy_module "$module"; then
            failed_modules+=("$module")
        fi
        echo ""
    done
    
    # Summary
    print_header "Destruction Summary"
    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        print_success "All modules destroyed successfully"
    else
        print_error "Failed to destroy modules: ${failed_modules[*]}"
        exit 1
    fi
else
    # Deployment
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
fi

echo ""
print_success "$([ "$DESTROY" = true ] && echo 'Destruction' || echo 'Deployment') completed!"
echo ""

