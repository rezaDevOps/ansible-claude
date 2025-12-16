#!/bin/bash
# Cleanup script to destroy all AWS resources
# Usage: ./scripts/cleanup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}=========================================="
echo "AWS Resource Cleanup Script"
echo "==========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

# Source variables from all.yml (basic parsing)
if [ -f "$PROJECT_ROOT/group_vars/all.yml" ]; then
    AWS_REGION=$(grep "^aws_region:" "$PROJECT_ROOT/group_vars/all.yml" | awk '{print $2}' | tr -d '"')
    SECURITY_GROUP_NAME=$(grep "^security_group_name:" "$PROJECT_ROOT/group_vars/all.yml" | awk '{print $2}' | tr -d '"')
    AWS_KEYPAIR_NAME=$(grep "^aws_keypair_name:" "$PROJECT_ROOT/group_vars/all.yml" | awk '{print $2}' | tr -d '"')
else
    echo -e "${RED}ERROR: group_vars/all.yml not found${NC}"
    exit 1
fi

echo "Configuration loaded:"
echo "  Region: $AWS_REGION"
echo "  Security Group: $SECURITY_GROUP_NAME"
echo "  Key Pair: $AWS_KEYPAIR_NAME"
echo ""

# Find instance
echo "Searching for EC2 instances..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=ansible-managed-ec2" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo -e "${YELLOW}No running instances found${NC}"
    INSTANCE_ID=""
else
    INSTANCE_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "no-ip")

    echo -e "${GREEN}Found instance:${NC}"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $INSTANCE_IP"
fi

# Check security group
echo ""
echo "Checking security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo -e "${YELLOW}Security group not found${NC}"
    SG_ID=""
else
    echo -e "${GREEN}Found security group: $SG_ID${NC}"
fi

# Check key pair
echo ""
echo "Checking key pair..."
KEY_EXISTS=$(aws ec2 describe-key-pairs \
    --key-names "$AWS_KEYPAIR_NAME" \
    --region "$AWS_REGION" 2>/dev/null && echo "yes" || echo "no")

if [ "$KEY_EXISTS" = "yes" ]; then
    echo -e "${GREEN}Found key pair: $AWS_KEYPAIR_NAME${NC}"
else
    echo -e "${YELLOW}Key pair not found${NC}"
fi

# Summary
echo ""
echo -e "${RED}=========================================="
echo "WARNING: The following will be DESTROYED:"
echo "==========================================${NC}"
[ -n "$INSTANCE_ID" ] && echo -e "${RED}  - EC2 Instance: $INSTANCE_ID${NC}"
[ -n "$SG_ID" ] && echo -e "${RED}  - Security Group: $SG_ID${NC}"
[ "$KEY_EXISTS" = "yes" ] && echo -e "${RED}  - Key Pair: $AWS_KEYPAIR_NAME${NC}"
echo ""

# Confirmation
read -p "Type 'yes' to confirm destruction: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Cleanup aborted${NC}"
    exit 0
fi

echo ""
echo -e "${RED}Starting cleanup in 5 seconds... (Press Ctrl+C to cancel)${NC}"
sleep 5

# Terminate instance
if [ -n "$INSTANCE_ID" ]; then
    echo ""
    echo "Terminating EC2 instance..."
    aws ec2 terminate-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" > /dev/null

    echo "Waiting for instance to terminate..."
    aws ec2 wait instance-terminated \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" 2>/dev/null || true

    echo -e "${GREEN}Instance terminated${NC}"
fi

# Delete security group
if [ -n "$SG_ID" ]; then
    echo ""
    echo "Deleting security group..."

    # Retry up to 5 times (sometimes needs time after instance termination)
    for i in {1..5}; do
        if aws ec2 delete-security-group \
            --group-id "$SG_ID" \
            --region "$AWS_REGION" 2>/dev/null; then
            echo -e "${GREEN}Security group deleted${NC}"
            break
        else
            if [ $i -eq 5 ]; then
                echo -e "${YELLOW}Warning: Could not delete security group (may need manual cleanup)${NC}"
            else
                echo "Retrying in 10 seconds... (attempt $i/5)"
                sleep 10
            fi
        fi
    done
fi

# Delete key pair
if [ "$KEY_EXISTS" = "yes" ]; then
    echo ""
    echo "Deleting key pair from AWS..."
    aws ec2 delete-key-pair \
        --key-name "$AWS_KEYPAIR_NAME" \
        --region "$AWS_REGION"

    echo -e "${GREEN}Key pair deleted from AWS${NC}"
fi

# Cleanup summary
echo ""
echo -e "${GREEN}=========================================="
echo "Cleanup completed successfully!"
echo "==========================================${NC}"
echo ""
echo "AWS resources destroyed:"
[ -n "$INSTANCE_ID" ] && echo "  ✓ EC2 instance terminated"
[ -n "$SG_ID" ] && echo "  ✓ Security group deleted"
[ "$KEY_EXISTS" = "yes" ] && echo "  ✓ Key pair deleted"
echo ""
echo -e "${YELLOW}Optional local cleanup:${NC}"
echo "  - Clear inventory: sed -i '' '5d' inventory/hosts.ini"
echo "  - Delete instance info: rm -f ec2_instance_info.txt"
echo "  - Remove SSH keys:"
echo "    rm -f ~/.ssh/ansible-ec2-key.pem"
echo "    rm -f ~/.ssh/deployer-key ~/.ssh/deployer-key.pub"
echo ""

# Create cleanup log
LOG_FILE="cleanup_log_$(date +%Y%m%d_%H%M%S).txt"
cat > "$LOG_FILE" <<EOF
AWS Cleanup Log
Generated: $(date +%Y-%m-%dT%H:%M:%S)

Region: $AWS_REGION
Instance ID: ${INSTANCE_ID:-none}
Instance IP: ${INSTANCE_IP:-none}
Security Group: ${SG_ID:-none}
Key Pair: ${AWS_KEYPAIR_NAME} (${KEY_EXISTS})

All AWS resources have been destroyed.
EOF

echo -e "${GREEN}Cleanup log saved to: $LOG_FILE${NC}"
