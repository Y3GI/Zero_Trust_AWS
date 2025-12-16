#!/bin/bash

# Force delete Secrets Manager secrets scheduled for deletion
# This script immediately deletes secrets without waiting for the recovery window

set -e

REGION="eu-north-1"
ENV="dev"

echo "🔒 Force Deleting Secrets Manager Secrets..."
echo "Region: $REGION"
echo "Environment: $ENV"
echo ""

# Function to force delete a secret
force_delete_secret() {
    local secret_name=$1
    
    echo -n "Processing secret: $secret_name ... "
    
    # Try to delete the secret with ForceDeleteWithoutRecovery
    if aws secretsmanager delete-secret \
        --secret-id "$secret_name" \
        --force-delete-without-recovery \
        --region "$REGION" 2>/dev/null; then
        echo "✅ Force deleted"
    else
        # If it doesn't exist or already deleted, that's fine
        echo "⚠️  Already deleted or not found"
    fi
}

# Delete both secrets
force_delete_secret "${ENV}/app/db-credentials"
force_delete_secret "${ENV}/app/api-keys"

echo ""
echo "✅ Force deletion complete!"
echo ""
echo "Verifying deletion..."
echo ""

# Verify they're gone
aws secretsmanager list-secrets \
    --region "$REGION" \
    --query "SecretList[?contains(Name, '${ENV}/app')].{Name:Name, Status:DeletedDate}" \
    --output table || echo "No secrets found"

echo ""
echo "You can now run: terraform apply -auto-approve"
