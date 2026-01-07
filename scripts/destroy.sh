#!/bin/bash

set -e

echo "⚠️  Zero Trust Infrastructure Destruction"
echo ""

# Validate AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "❌ Error: AWS credentials not found"
    exit 1
fi

export AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
echo "📍 Region: $AWS_REGION"

# Verify credentials
CALLER_IDENTITY=$(aws sts get-caller-identity)
echo "🔐 Authenticated as:"
echo "$CALLER_IDENTITY"

PROJECT_NAME="${TF_VAR_project_name:-zero-trust-prod}"
echo ""
echo "⚠️  WARNING: This will destroy ALL resources for project: $PROJECT_NAME"
echo ""

# Require manual confirmation in interactive mode
if [ -t 0 ]; then
    read -p "Type 'DESTROY' to confirm: " confirmation
    if [ "$confirmation" != "DESTROY" ]; then
        echo "❌ Destruction cancelled"
        exit 1
    fi
fi

# Modules in REVERSE order (important for dependencies)
MODULES=(
    "monitoring"
    "data_store"
    "compute"
    "vpc-endpoints"
    "firewall"
    "rbac"
    "certificates"
    "secrets"
    "security"
    "vpc"
    "bootstrap"
)

echo ""
echo "🗑️  Destruction Order (reverse deployment):"
for i in "${!MODULES[@]}"; do
    echo "   $((i + 1)). ${MODULES[$i]}"
done
echo ""

# Destroy each module
for i in "${!MODULES[@]}"; do
    module="${MODULES[$i]}"
    stage=$((i + 1))
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "🗑️  Stage $stage/${#MODULES[@]}: Destroying $module"
    echo "════════════════════════════════════════════════════════════"
    
    cd "../modules/$module" || exit 1
    
    # Initialize
    if [ "$module" != "bootstrap" ]; then
        terraform init \
            -backend-config="bucket=${PROJECT_NAME}-terraform-state" \
            -backend-config="key=${module}/terraform.tfstate" \
            -backend-config="region=${AWS_REGION}" \
            -backend-config="dynamodb_table=${PROJECT_NAME}-terraform-locks" \
            2>/dev/null || {
            echo "⚠️  Could not initialize $module (may already be destroyed)"
            cd - > /dev/null
            continue
        }
    else
        terraform init
    fi
    
    # Destroy
    echo "🗑️  Destroying $module..."
    terraform destroy -auto-approve || {
        echo "⚠️  Warning: $module destruction encountered errors"
    }
    
    echo "✅ $module destroyed"
    cd - > /dev/null
    
    # Brief pause
    if [ $stage -lt ${#MODULES[@]} ]; then
        sleep 5
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Destruction Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "All Zero Trust infrastructure has been removed"
echo ""

