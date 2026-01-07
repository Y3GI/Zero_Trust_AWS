#!/bin/bash

################################################################################
# ZTNA Deploy Script
# Purpose: Deploy ZTNA infrastructure to AWS in correct dependency order
# Usage: ./scripts/deploy.sh [--destroy] [--module=MODULE_NAME]
################################################################################

set -e

echo "🚀 Starting Zero Trust Infrastructure Deployment"

# Validate AWS credentials (provided by GitHub Actions OIDC)
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "❌ Error: AWS credentials not found"
    echo "Ensure GitHub Actions workflow has configured OIDC authentication"
    exit 1
fi

echo "✅ AWS credentials configured via OIDC"
export AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
echo "📍 Deploying to region: $AWS_REGION"

# Verify AWS access
echo "🔍 Verifying AWS access..."
CALLER_IDENTITY=$(aws sts get-caller-identity)
echo "$CALLER_IDENTITY"

ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')
echo "📋 AWS Account: $ACCOUNT_ID"

# Deployment configuration
PROJECT_NAME="${TF_VAR_project_name:-zero-trust-prod}"
echo "🏷️  Project: $PROJECT_NAME"

# Array of modules in correct deployment order
MODULES=(
    "bootstrap"
    "vpc"
    "security"
    "secrets"
    "certificates"
    "rbac"
    "firewall"
    "vpc-endpoints"
    "compute"
    "data_store"
    "monitoring"
)

echo ""
echo "📋 Deployment Plan:"
echo "   Modules: ${#MODULES[@]}"
echo "   Order: Sequential (dependency-based)"
echo ""

# Deploy each module
for i in "${!MODULES[@]}"; do
    module="${MODULES[$i]}"
    stage=$((i + 1))
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "📦 Stage $stage/${#MODULES[@]}: Deploying $module"
    echo "════════════════════════════════════════════════════════════"
    
    cd "../modules/$module" || exit 1
    
    # Initialize with remote backend (if bootstrap is already deployed)
    if [ "$module" != "bootstrap" ]; then
        terraform init \
            -backend-config="bucket=${PROJECT_NAME}-terraform-state" \
            -backend-config="key=${module}/terraform.tfstate" \
            -backend-config="region=${AWS_REGION}" \
            -backend-config="dynamodb_table=${PROJECT_NAME}-terraform-locks"
    else
        terraform init
    fi
    
    # Plan
    echo "📋 Planning $module deployment..."
    terraform plan -out=tfplan
    
    # Apply
    echo "🚀 Applying $module..."
    terraform apply tfplan
    
    echo "✅ $module deployed successfully"
    cd - > /dev/null
    
    # Brief pause between modules
    if [ $stage -lt ${#MODULES[@]} ]; then
        echo "⏳ Waiting 10s before next module..."
        sleep 10
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎉 Deployment Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "✅ All 11 modules deployed successfully"
echo "🔐 Zero Trust infrastructure is now active"
echo ""

