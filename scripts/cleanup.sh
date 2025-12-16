#!/bin/bash

################################################################################
# ZTNA Cleanup Script
# Purpose: Clean up orphaned AWS resources when Terraform state is lost
# Usage: ./scripts/cleanup.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REGION="eu-north-1"

# Function to print headers
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header "ZTNA Orphaned Resources Cleanup"

print_warning "This will delete ALL ZTNA resources (VPCs, EC2, DynamoDB, etc.) with tag Project=ztna-aws-1"
echo ""

# Confirmation
read -p "Type 'yes' to proceed with cleanup: " -r
echo ""
if [[ ! $REPLY == "yes" ]]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

echo ""
print_header "Deleting Orphaned Resources"

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Project,Values=ztna-aws-1" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [[ "$VPC_ID" == "None" ]] || [[ -z "$VPC_ID" ]]; then
    print_info "No ZTNA VPCs found"
    exit 0
fi

print_info "Found VPC: $VPC_ID"

# Delete EC2 Instances
print_info "Deleting EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null)
if [[ ! -z "$INSTANCE_IDS" ]]; then
    for instance_id in $INSTANCE_IDS; do
        print_info "  Terminating instance: $instance_id"
        aws ec2 terminate-instances --region "$REGION" --instance-ids "$instance_id" > /dev/null 2>&1
    done
    print_info "  Waiting for instances to terminate..."
    sleep 30
fi

# Delete VPC Endpoints
print_info "Deleting VPC Endpoints..."
ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[*].VpcEndpointId' --output text 2>/dev/null)
if [[ ! -z "$ENDPOINT_IDS" ]]; then
    for endpoint_id in $ENDPOINT_IDS; do
        print_info "  Deleting endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoints --region "$REGION" --vpc-endpoint-ids "$endpoint_id" > /dev/null 2>&1
    done
fi

# Delete Network Interfaces (Security Groups references)
print_info "Cleaning up network interfaces..."
ENI_IDS=$(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null)
for eni_id in $ENI_IDS; do
    # Detach from instances if needed
    aws ec2 describe-network-interface-attribute --region "$REGION" --network-interface-id "$eni_id" --attribute attachment > /dev/null 2>&1 && \
    aws ec2 detach-network-interface --region "$REGION" --attachment-id "$(aws ec2 describe-network-interface-attribute --region "$REGION" --network-interface-id "$eni_id" --attribute attachment --query 'Attachment.AttachmentId' --output text 2>/dev/null)" > /dev/null 2>&1 || true
done

# Delete Security Groups
print_info "Deleting Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[*].GroupId' --output text 2>/dev/null)
if [[ ! -z "$SG_IDS" ]]; then
    for sg_id in $SG_IDS; do
        # Skip default security group
        if [[ "$sg_id" != "sg-"* ]] || [[ $(aws ec2 describe-security-groups --region "$REGION" --group-ids "$sg_id" --query 'SecurityGroups[0].GroupName' --output text 2>/dev/null) == "default" ]]; then
            continue
        fi
        print_info "  Deleting security group: $sg_id"
        aws ec2 delete-security-group --region "$REGION" --group-id "$sg_id" > /dev/null 2>&1 || true
    done
fi

# Delete Route Tables
print_info "Deleting Route Tables..."
RT_IDS=$(aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' --output text 2>/dev/null)
if [[ ! -z "$RT_IDS" ]]; then
    for rt_id in $RT_IDS; do
        print_info "  Deleting route table: $rt_id"
        aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt_id" > /dev/null 2>&1 || true
    done
fi

# Delete Subnets
print_info "Deleting Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text 2>/dev/null)
if [[ ! -z "$SUBNET_IDS" ]]; then
    for subnet_id in $SUBNET_IDS; do
        print_info "  Deleting subnet: $subnet_id"
        aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet_id" > /dev/null 2>&1 || true
    done
fi

# Delete Internet Gateway
print_info "Deleting Internet Gateway..."
IGW_IDS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[*].InternetGatewayId' --output text 2>/dev/null)
if [[ ! -z "$IGW_IDS" ]]; then
    for igw_id in $IGW_IDS; do
        print_info "  Detaching and deleting IGW: $igw_id"
        aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw_id" --vpc-id "$VPC_ID" > /dev/null 2>&1 || true
        aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw_id" > /dev/null 2>&1 || true
    done
fi

# Delete NAT Gateways
print_info "Deleting NAT Gateways..."
NAT_IDS=$(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null)
if [[ ! -z "$NAT_IDS" ]]; then
    for nat_id in $NAT_IDS; do
        print_info "  Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --region "$REGION" --nat-gateway-id "$nat_id" > /dev/null 2>&1 || true
    done
    print_info "  Waiting for NAT Gateways to delete..."
    sleep 10
fi

# Delete Elastic IPs
print_info "Deleting Elastic IPs..."
EIP_ALLOC=$(aws ec2 describe-addresses --region "$REGION" --query 'Addresses[*].AllocationId' --output text 2>/dev/null)
if [[ ! -z "$EIP_ALLOC" ]]; then
    for eip in $EIP_ALLOC; do
        print_info "  Deleting Elastic IP: $eip"
        aws ec2 release-address --region "$REGION" --allocation-id "$eip" > /dev/null 2>&1 || true
    done
fi

# Delete VPC
print_info "Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID" > /dev/null 2>&1 || print_warning "Could not delete VPC (may have dependencies)"

# Delete DynamoDB Tables
print_info "Deleting DynamoDB tables..."
TABLE_NAMES=$(aws dynamodb list-tables --region "$REGION" --query "TableNames[?contains(@, 'ztna')]" --output text 2>/dev/null)
if [[ ! -z "$TABLE_NAMES" ]]; then
    for table_name in $TABLE_NAMES; do
        print_info "  Deleting table: $table_name"
        aws dynamodb delete-table --region "$REGION" --table-name "$table_name" > /dev/null 2>&1 || true
    done
fi

# Delete Secrets
print_info "Deleting Secrets Manager secrets..."
SECRET_ARNS=$(aws secretsmanager list-secrets --region "$REGION" --query "SecretList[?contains(Name, 'dev')].ARN" --output text 2>/dev/null)
if [[ ! -z "$SECRET_ARNS" ]]; then
    for secret_arn in $SECRET_ARNS; do
        print_info "  Deleting secret: $secret_arn"
        aws secretsmanager delete-secret --region "$REGION" --secret-id "$secret_arn" --force-delete-without-recovery > /dev/null 2>&1 || true
    done
fi

echo ""
print_header "Cleanup Complete"
print_success "Orphaned resources have been deleted"
print_info "You can now run ./deploy.sh to create fresh infrastructure"
echo ""
