#!/bin/bash

# Script to update k8s/security/external-secrets.yaml with correct secret names and keys
# This script updates AWS Secrets Manager key names, Kubernetes secret names, and other configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXTERNAL_SECRETS_FILE="$PROJECT_ROOT/k8s/security/external-secrets.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 External Secrets Configuration Updater${NC}"
echo ""

# Check if file exists
if [ ! -f "$EXTERNAL_SECRETS_FILE" ]; then
    echo -e "${RED}❌ External secrets file not found: $EXTERNAL_SECRETS_FILE${NC}"
    exit 1
fi

# Default values
DEFAULT_NAMESPACE="prod"
DEFAULT_AWS_REGION="us-east-1"
DEFAULT_AWS_SECRETS_PREFIX="eventsphere"
DEFAULT_SERVICE_ACCOUNT="external-secrets"
DEFAULT_MONGODB_SECRET_NAME="mongodb-secret"
DEFAULT_AUTH_SERVICE_SECRET_NAME="auth-service-secret"

# Configuration via environment variables or prompts
NAMESPACE="${EXTERNAL_SECRETS_NAMESPACE:-$DEFAULT_NAMESPACE}"
AWS_REGION="${EXTERNAL_SECRETS_AWS_REGION:-$DEFAULT_AWS_REGION}"
AWS_SECRETS_PREFIX="${EXTERNAL_SECRETS_PREFIX:-$DEFAULT_AWS_SECRETS_PREFIX}"
SERVICE_ACCOUNT="${EXTERNAL_SECRETS_SERVICE_ACCOUNT:-$DEFAULT_SERVICE_ACCOUNT}"
MONGODB_SECRET_NAME="${MONGODB_SECRET_NAME:-$DEFAULT_MONGODB_SECRET_NAME}"
AUTH_SERVICE_SECRET_NAME="${AUTH_SERVICE_SECRET_NAME:-$DEFAULT_AUTH_SERVICE_SECRET_NAME}"

# AWS Secrets Manager key names
MONGODB_AWS_KEY="${MONGODB_AWS_KEY:-$AWS_SECRETS_PREFIX/mongodb}"
AUTH_SERVICE_AWS_KEY="${AUTH_SERVICE_AWS_KEY:-$AWS_SECRETS_PREFIX/auth-service}"

# Display current configuration
echo -e "${YELLOW}Current Configuration:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Secrets Prefix: $AWS_SECRETS_PREFIX"
echo "  Service Account: $SERVICE_ACCOUNT"
echo "  MongoDB Secret Name: $MONGODB_SECRET_NAME"
echo "  Auth Service Secret Name: $AUTH_SERVICE_SECRET_NAME"
echo "  MongoDB AWS Key: $MONGODB_AWS_KEY"
echo "  Auth Service AWS Key: $AUTH_SERVICE_AWS_KEY"
echo ""

# Ask for confirmation or allow override via environment variables
if [ -z "${EXTERNAL_SECRETS_AUTO_CONFIRM:-}" ]; then
    read -p "Use these values? (y/n) [y]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Exiting. Set environment variables to override defaults:"
        echo "  EXTERNAL_SECRETS_NAMESPACE"
        echo "  EXTERNAL_SECRETS_AWS_REGION"
        echo "  EXTERNAL_SECRETS_PREFIX"
        echo "  EXTERNAL_SECRETS_SERVICE_ACCOUNT"
        echo "  MONGODB_SECRET_NAME"
        echo "  AUTH_SERVICE_SECRET_NAME"
        echo "  MONGODB_AWS_KEY"
        echo "  AUTH_SERVICE_AWS_KEY"
        exit 0
    fi
fi

# Create backup
BACKUP_FILE="${EXTERNAL_SECRETS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$EXTERNAL_SECRETS_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Created backup: $BACKUP_FILE${NC}"

echo ""
echo -e "${BLUE}📝 Updating external-secrets.yaml...${NC}"

# Function to perform sed replacement (cross-platform compatible)
perform_sed_replace() {
    local pattern="$1"
    local replacement="$2"
    local file="$3"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|${pattern}|${replacement}|g" "$file"
    else
        sed -i "s|${pattern}|${replacement}|g" "$file"
    fi
}

# Update SecretStore
echo "  Updating SecretStore configuration..."
# Update all namespace occurrences (SecretStore and ExternalSecrets)
perform_sed_replace "^  namespace: prod$" "  namespace: ${NAMESPACE}" "$EXTERNAL_SECRETS_FILE"
perform_sed_replace "^      region:.*" "      region: ${AWS_REGION}" "$EXTERNAL_SECRETS_FILE"
perform_sed_replace "^            name: external-secrets$" "            name: ${SERVICE_ACCOUNT}" "$EXTERNAL_SECRETS_FILE"

# Update MongoDB ExternalSecret
echo "  Updating MongoDB ExternalSecret..."

# Update secret name in metadata and target
perform_sed_replace "^  name: mongodb-secret$" "  name: ${MONGODB_SECRET_NAME}" "$EXTERNAL_SECRETS_FILE"
perform_sed_replace "^    name: mongodb-secret$" "    name: ${MONGODB_SECRET_NAME}" "$EXTERNAL_SECRETS_FILE"

# Update AWS Secrets Manager key for MongoDB
perform_sed_replace "key: eventsphere/mongodb" "key: ${MONGODB_AWS_KEY}" "$EXTERNAL_SECRETS_FILE"

# Update Auth Service ExternalSecret
echo "  Updating Auth Service ExternalSecret..."
# Update secret name in metadata and target
perform_sed_replace "^  name: auth-service-secret$" "  name: ${AUTH_SERVICE_SECRET_NAME}" "$EXTERNAL_SECRETS_FILE"
perform_sed_replace "^    name: auth-service-secret$" "    name: ${AUTH_SERVICE_SECRET_NAME}" "$EXTERNAL_SECRETS_FILE"

# Update AWS Secrets Manager key for Auth Service
perform_sed_replace "key: eventsphere/auth-service" "key: ${AUTH_SERVICE_AWS_KEY}" "$EXTERNAL_SECRETS_FILE"

echo ""
echo -e "${GREEN}✅ External secrets configuration updated successfully!${NC}"
echo ""
echo -e "${BLUE}Summary of changes:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  AWS Region: $AWS_REGION"
echo "  Service Account: $SERVICE_ACCOUNT"
echo "  MongoDB Secret:"
echo "    - Kubernetes name: $MONGODB_SECRET_NAME"
echo "    - AWS Secrets Manager key: $MONGODB_AWS_KEY"
echo "    - Keys: username, password, connection-string"
echo "  Auth Service Secret:"
echo "    - Kubernetes name: $AUTH_SERVICE_SECRET_NAME"
echo "    - AWS Secrets Manager key: $AUTH_SERVICE_AWS_KEY"
echo "    - Keys: jwt-secret"
echo ""
echo -e "${YELLOW}⚠️  Next steps:${NC}"
echo "  1. Ensure secrets exist in AWS Secrets Manager:"
echo "     - $MONGODB_AWS_KEY (with properties: username, password, connection-string)"
echo "     - $AUTH_SERVICE_AWS_KEY (with property: jwt-secret)"
echo "  2. Verify the External Secrets Operator is installed:"
echo "     kubectl get pods -n external-secrets-system"
echo "  3. Apply the updated configuration:"
echo "     kubectl apply -f $EXTERNAL_SECRETS_FILE"
echo "  4. Verify secrets are synced:"
echo "     kubectl get externalsecrets -n $NAMESPACE"
echo "     kubectl get secrets -n $NAMESPACE"
echo ""
echo -e "${GREEN}Backup saved to: $BACKUP_FILE${NC}"

