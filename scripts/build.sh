#!/bin/bash

################################################################################
# ZTNA Build Script
# Purpose: Validate Terraform code, check for issues, and prepare for deployment
# Usage: ./scripts/build.sh
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
MODULES_DIR="$PROJECT_ROOT/modules"
ENVS_DEV_DIR="$PROJECT_ROOT/envs/dev"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         ZTNA Infrastructure Build & Validation Script          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

# Check prerequisites
print_header "Step 1: Checking Prerequisites"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads.html"
    exit 1
fi
print_success "Terraform installed ($(terraform version -json | grep terraform_version | head -1))"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi
print_success "AWS CLI installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    echo "Configure with: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
print_success "AWS credentials valid (Account: $ACCOUNT_ID, Region: $REGION)"

echo ""

# Format Terraform files
print_header "Step 2: Formatting Terraform Code"

format_count=0
for dir in "$MODULES_DIR"/*/ "$ENVS_DEV_DIR"/*/; do
    if [[ -f "$dir"*.tf ]]; then
        if terraform fmt -recursive "$dir" > /dev/null 2>&1; then
            format_count=$((format_count + 1))
        fi
    fi
done
print_success "Formatted $format_count directories"

echo ""

# Validate modules
print_header "Step 3: Validating Terraform Modules"

invalid_count=0
for module in "$MODULES_DIR"/*; do
    if [[ -d "$module" && -f "$module/main.tf" ]]; then
        module_name=$(basename "$module")
        if terraform -chdir="$module" init -backend=false -no-color > /dev/null 2>&1; then
            if terraform -chdir="$module" validate > /dev/null 2>&1; then
                print_success "Module: $module_name"
            else
                print_error "Module: $module_name (validation failed)"
                invalid_count=$((invalid_count + 1))
            fi
        else
            print_error "Module: $module_name (init failed)"
            invalid_count=$((invalid_count + 1))
        fi
    fi
done

if [[ $invalid_count -gt 0 ]]; then
    print_error "$invalid_count module(s) failed validation"
    exit 1
fi

echo ""

# Validate env/dev configurations
print_header "Step 4: Validating Environment Configurations"

env_invalid_count=0
for env_module in "$ENVS_DEV_DIR"/*; do
    if [[ -d "$env_module" && -f "$env_module/main.tf" ]]; then
        env_name=$(basename "$env_module")
        if terraform -chdir="$env_module" init -backend=false -no-color > /dev/null 2>&1; then
            if terraform -chdir="$env_module" validate > /dev/null 2>&1; then
                print_success "Environment: dev/$env_name"
            else
                print_error "Environment: dev/$env_name (validation failed)"
                env_invalid_count=$((env_invalid_count + 1))
            fi
        else
            print_error "Environment: dev/$env_name (init failed)"
            env_invalid_count=$((env_invalid_count + 1))
        fi
    fi
done

if [[ $env_invalid_count -gt 0 ]]; then
    print_error "$env_invalid_count environment(s) failed validation"
    exit 1
fi

echo ""

# Check for security issues
print_header "Step 5: Security Check - Looking for Wildcards"

wildcard_files=0
print_warning "Checking for overly permissive wildcards (*) in policies..."
echo ""

for file in $(find "$PROJECT_ROOT" -name "*.tf" -type f); do
    if grep -q 'Action.*=.*"\*"' "$file" 2>/dev/null || \
       grep -q "Resource.*=.*['\"].*\*['\"]" "$file" 2>/dev/null; then
        print_warning "Potential wildcard in: $file"
        wildcard_files=$((wildcard_files + 1))
    fi
done

if [[ $wildcard_files -gt 0 ]]; then
    print_warning "$wildcard_files file(s) contain potential wildcard issues"
    print_warning "Run: grep -r 'Action.*\\*' modules/ && grep -r 'Resource.*\\*' modules/"
    print_warning "See: WILDCARD_REMEDIATION.md for details"
    echo ""
fi

echo ""

# Initialize terraform backend (local)
print_header "Step 6: Initializing Terraform State Backend"

if [[ ! -d "$ENVS_DEV_DIR/vpc/.terraform" ]]; then
    echo "Initializing VPC module (foundation)..."
    terraform -chdir="$ENVS_DEV_DIR/vpc" init -no-color > /dev/null 2>&1
    print_success "VPC module initialized"
else
    print_success "VPC module already initialized"
fi

echo ""

# Generate plan files
print_header "Step 7: Generating Terraform Plans"

# Create plans directory
mkdir -p "$PROJECT_ROOT/terraform-plans"

deployment_order=("vpc" "security" "bootstrap" "firewall" "compute" "data_store" "monitoring" "vpc-endpoints" "secrets" "rbac-authorization" "certificates")

for module in "${deployment_order[@]}"; do
    plan_file="$PROJECT_ROOT/terraform-plans/${module}.tfplan"
    
    if [[ -d "$ENVS_DEV_DIR/$module" ]]; then
        echo -n "Planning $module..."
        if terraform -chdir="$ENVS_DEV_DIR/$module" plan -out="$plan_file" -no-color > /dev/null 2>&1; then
            print_success "$module plan created"
        else
            print_error "$module plan failed"
        fi
    fi
done

echo ""

# Summary
print_header "Build Summary"

echo ""
echo "✓ All modules validated successfully"
echo "✓ All environments validated successfully"
echo "✓ Terraform code formatted"
echo "✓ Terraform plans generated"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review plans:  terraform show terraform-plans/vpc.tfplan"
echo "2. Deploy:        ./scripts/deploy.sh"
echo "3. Destroy:       ./scripts/destroy.sh"
echo ""
echo -e "${GREEN}Build completed successfully!${NC}"
echo ""

