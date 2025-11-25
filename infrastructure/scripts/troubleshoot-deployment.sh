#!/bin/bash

# EventSphere Deployment Troubleshooting Script
# Helps diagnose issues with deployments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="${1:-prod}"
DEPLOYMENT="${2:-}"

echo -e "${BLUE}🔍 EventSphere Deployment Troubleshooting${NC}"
echo ""

if [ -z "$DEPLOYMENT" ]; then
    echo "Usage: $0 [NAMESPACE] [DEPLOYMENT_NAME]"
    echo ""
    echo "Examples:"
    echo "  $0 prod auth-service"
    echo "  $0 prod event-service"
    echo "  $0 prod"
    echo ""
    echo "If deployment name is omitted, shows status of all deployments in namespace."
    exit 0
fi

echo -e "${BLUE}Namespace: $NAMESPACE${NC}"
echo -e "${BLUE}Deployment: $DEPLOYMENT${NC}"
echo ""

# Check if deployment exists
if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}❌ Deployment $DEPLOYMENT not found in namespace $NAMESPACE${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}1. Deployment Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}2. Detailed Deployment Description${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}3. ReplicaSet Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get rs -n "$NAMESPACE" -l app="$DEPLOYMENT"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}4. Pod Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT" -o wide
echo ""

# Get pod details
PODS=$(kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT" -o jsonpath='{.items[*].metadata.name}')

for pod in $PODS; do
    if [ -n "$pod" ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}5. Pod Details: $pod${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        kubectl describe pod "$pod" -n "$NAMESPACE"
        echo ""
        
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}6. Pod Events: $pod${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$pod" --sort-by='.lastTimestamp' | tail -20
        echo ""
        
        # Check container status
        CONTAINER_STATUS=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
        
        if [ "$CONTAINER_STATUS" = "true" ]; then
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}7. Container Logs: $pod${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=50 2>&1 || echo "Could not retrieve logs"
        else
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}7. Init Container and Main Container Logs: $pod${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo "All container logs:"
            kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true --tail=50 2>&1 || echo "Could not retrieve logs"
        fi
        echo ""
    fi
done

# Check for common issues
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}8. Common Issues Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check secrets
echo "Checking required secrets..."
REQUIRED_SECRETS="mongodb-secret auth-service-secret"
for secret in $REQUIRED_SECRETS; do
    if kubectl get secret "$secret" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ Secret $secret exists${NC}"
    else
        echo -e "${RED}❌ Secret $secret is missing!${NC}"
    fi
done
echo ""

# Check ConfigMaps
echo "Checking ConfigMaps..."
CONFIGMAP_NAME="${DEPLOYMENT}-config"
if kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✅ ConfigMap $CONFIGMAP_NAME exists${NC}"
else
    echo -e "${YELLOW}⚠️  ConfigMap $CONFIGMAP_NAME not found (may be optional)${NC}"
fi
echo ""

# Check image pull issues
echo "Checking for image pull issues..."
for pod in $PODS; do
    if [ -n "$pod" ]; then
        IMAGE_PULL_ERROR=$(kubectl describe pod "$pod" -n "$NAMESPACE" | grep -i "imagepull\|errimagepull\|pull" || true)
        if [ -n "$IMAGE_PULL_ERROR" ]; then
            echo -e "${RED}❌ Image pull issue detected for $pod:${NC}"
            echo "$IMAGE_PULL_ERROR"
        fi
    fi
done
echo ""

# Check resource constraints
echo "Checking node resources..."
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

# Summary and recommendations
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}9. Recommendations${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Common fixes:"
echo "  1. If image pull errors:"
echo "     - Verify ECR authentication: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin"
echo "     - Check image exists: aws ecr describe-images --repository-name <service-name>"
echo ""
echo "  2. If secrets missing:"
echo "     - Run: kubectl get secrets -n $NAMESPACE"
echo "     - Create secrets: ./infrastructure/scripts/deploy-services.sh --skip-services"
echo ""
echo "  3. If resource constraints:"
echo "     - Check node capacity: kubectl describe nodes"
echo "     - Scale cluster: eksctl scale nodegroup --cluster eventsphere-cluster --name <nodegroup> --nodes <count>"
echo ""
echo "  4. If configuration errors:"
echo "     - Check ConfigMap: kubectl get configmap ${DEPLOYMENT}-config -n $NAMESPACE -o yaml"
echo "     - Verify environment variables in deployment"
echo ""
echo "  5. Restart deployment:"
echo "     kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE"
echo ""

