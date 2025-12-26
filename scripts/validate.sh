#!/bin/bash

# Terraform Validation Script
# Validates Terraform code without generating plans
# Checks syntax, variable declarations, and module references

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVS_DIR="$PROJECT_ROOT/envs/dev"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Deployment order (foundation first, then dependent modules)
MODULES=(
    "vpc"
    "security"
    "bootstrap"
    "compute"
    "firewall"
    "data_store"
    "monitoring"
    "vpc-endpoints"
    "secrets"
    "rbac-authorization"
    "certificates"
)

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Terraform Code Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL_MODULES=${#MODULES[@]}
PASSED=0
FAILED=0
FAILED_MODULES=()

for MODULE in "${MODULES[@]}"; do
    MODULE_PATH="$ENVS_DIR/$MODULE"
    
    if [ ! -d "$MODULE_PATH" ]; then
        echo -e "${YELLOW}⏭️  $MODULE${NC} - Directory not found, skipping"
        continue
    fi
    
    echo -n "Validating $MODULE ... "
    
    # Initialize terraform (required for validation)
    if cd "$MODULE_PATH" && terraform init -upgrade > /dev/null 2>&1; then
        # Run validate
        if terraform validate > /tmp/validate_output.txt 2>&1; then
            echo -e "${GREEN}✅ PASSED${NC}"
            ((PASSED++))
        else
            echo -e "${RED}❌ FAILED${NC}"
            echo "$(cat /tmp/validate_output.txt)"
            ((FAILED++))
            FAILED_MODULES+=("$MODULE")
        fi
    else
        echo -e "${RED}❌ INIT FAILED${NC}"
        ((FAILED++))
        FAILED_MODULES+=("$MODULE")
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "Total Modules: ${TOTAL_MODULES}"
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"

if [ ${#FAILED_MODULES[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed Modules:${NC}"
    for mod in "${FAILED_MODULES[@]}"; do
        echo -e "  - ${RED}$mod${NC}"
    done
    echo ""
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ All modules validated successfully!${NC}"
    exit 0
fi
