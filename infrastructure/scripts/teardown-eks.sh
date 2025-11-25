#!/bin/bash

# EventSphere EKS Cluster Teardown Script
# WARNING: This will delete the entire cluster and all resources

set -e

CLUSTER_NAME="eventsphere-cluster"
REGION="us-east-1"

echo "⚠️  WARNING: This will delete the EKS cluster '$CLUSTER_NAME' and all resources!"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Teardown cancelled"
    exit 1
fi

echo "🗑️  Deleting EKS cluster..."

# Delete cluster
eksctl delete cluster --name $CLUSTER_NAME --region $REGION

echo "✅ Cluster deletion initiated. This may take 10-15 minutes."
echo "   You can monitor progress in the AWS Console."




