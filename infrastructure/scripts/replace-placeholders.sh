#!/bin/bash

# DEPRECATED: This script is deprecated in favor of process-templates.sh
# This script is kept for backward compatibility but will redirect to the new template-based approach

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  WARNING: replace-placeholders.sh is deprecated!"
echo "   Please use process-templates.sh instead for a more flexible template-based approach."
echo ""
echo "   Redirecting to process-templates.sh..."
echo ""

# Redirect to new script
exec "$SCRIPT_DIR/process-templates.sh" "$@"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Starting placeholder replacement..."

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure'${NC}"
    exit 1
fi

# Get AWS Account ID
echo "📋 Retrieving AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Failed to retrieve AWS Account ID${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS Account ID: $AWS_ACCOUNT_ID${NC}"

# Get Certificate ARN
# Priority: Environment variable > User input > AWS CLI lookup
CERTIFICATE_ARN="${ACM_CERTIFICATE_ARN:-}"

if [ -z "$CERTIFICATE_ARN" ]; then
    echo -e "${YELLOW}⚠️  ACM_CERTIFICATE_ARN environment variable not set${NC}"
    echo "Attempting to find certificate for enpm818rgroup7.work.gd..."
    
    # Try to find certificate by domain name
    CERTIFICATE_ARN=$(aws acm list-certificates --region us-east-1 \
        --query "CertificateSummaryList[?DomainName=='enpm818rgroup7.work.gd' || contains(SubjectAlternativeNameList, 'enpm818rgroup7.work.gd')].CertificateArn" \
        --output text | head -1)
    
    if [ -z "$CERTIFICATE_ARN" ] || [ "$CERTIFICATE_ARN" == "None" ]; then
        echo -e "${YELLOW}⚠️  Certificate not found automatically${NC}"
        echo "Please provide the ACM Certificate ARN:"
        echo "  Option 1: Set ACM_CERTIFICATE_ARN environment variable"
        echo "  Option 2: Provide it when prompted"
        read -p "ACM Certificate ARN (or press Enter to skip): " CERTIFICATE_ARN
    fi
fi

if [ -n "$CERTIFICATE_ARN" ] && [ "$CERTIFICATE_ARN" != "None" ]; then
    echo -e "${GREEN}✅ Using Certificate ARN: $CERTIFICATE_ARN${NC}"
else
    echo -e "${YELLOW}⚠️  No certificate ARN provided. Certificate placeholders will not be replaced.${NC}"
    echo "  You can set ACM_CERTIFICATE_ARN environment variable or update manually."
fi

# Function to replace placeholders in a file
replace_in_file() {
    local file="$1"
    local account_id="$2"
    local cert_arn="$3"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  File not found: $file${NC}"
        return 1
    fi
    
    # Replace <ACCOUNT_ID> with actual account ID
    if grep -q "<ACCOUNT_ID>" "$file"; then
        # Use different sed syntax for macOS vs Linux
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|<ACCOUNT_ID>|$account_id|g" "$file"
        else
            sed -i "s|<ACCOUNT_ID>|$account_id|g" "$file"
        fi
        echo -e "${GREEN}✅ Replaced <ACCOUNT_ID> in $file${NC}"
    fi
    
    # Replace <CERTIFICATE_ID> with actual certificate ARN (if provided)
    if [ -n "$cert_arn" ] && [ "$cert_arn" != "None" ]; then
        if grep -q "<CERTIFICATE_ID>" "$file"; then
            # Escape special characters in ARN for sed
            cert_arn_escaped=$(echo "$cert_arn" | sed 's/[[\.*^$()+?{|]/\\&/g')
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|<CERTIFICATE_ID>|$cert_arn_escaped|g" "$file"
            else
                sed -i "s|<CERTIFICATE_ID>|$cert_arn_escaped|g" "$file"
            fi
            echo -e "${GREEN}✅ Replaced <CERTIFICATE_ID> in $file${NC}"
        fi
    fi
}

# Files to update
FILES=(
    "$PROJECT_ROOT/k8s/base/rbac.yaml"
    "$PROJECT_ROOT/k8s/ingress/ingress.yaml"
    "$PROJECT_ROOT/monitoring/cloudwatch/fluent-bit-config.yaml"
)

# Replace placeholders in each file
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        replace_in_file "$file" "$AWS_ACCOUNT_ID" "$CERTIFICATE_ARN"
    else
        echo -e "${YELLOW}⚠️  Skipping missing file: $file${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Placeholder replacement completed!${NC}"
echo ""
echo "Summary:"
echo "  - AWS Account ID: $AWS_ACCOUNT_ID"
if [ -n "$CERTIFICATE_ARN" ] && [ "$CERTIFICATE_ARN" != "None" ]; then
    echo "  - Certificate ARN: $CERTIFICATE_ARN"
else
    echo "  - Certificate ARN: Not replaced (set ACM_CERTIFICATE_ARN to replace)"
fi
echo ""
echo "Updated files:"
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  - $file"
    fi
done





