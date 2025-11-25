#!/bin/bash

# EventSphere EKS Cluster Setup Script
# This script sets up the EKS cluster and installs required add-ons

set -e

CLUSTER_NAME="eventsphere-cluster"
REGION="us-east-1"

echo "🚀 Starting EKS cluster setup for EventSphere..."

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl is not installed. Please install it first:"
    echo "   https://github.com/weaveworks/eksctl"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first:"
    echo "   https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ helm is not installed. Please install it first:"
    echo "   https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Create EKS cluster
echo "📦 Creating EKS cluster..."
eksctl create cluster -f eksctl-cluster.yaml

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Verify cluster access
echo "🔍 Verifying cluster access..."
kubectl cluster-info
kubectl get nodes -o wide

# Install AWS Load Balancer Controller
echo "📥 Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# Wait for AWS Load Balancer Controller to be ready
echo "⏳ Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Install Cluster Autoscaler
echo "📥 Installing Cluster Autoscaler..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Patch Cluster Autoscaler deployment
kubectl patch deployment cluster-autoscaler \
  -n kube-system \
  -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict":"false"}}}}}'

# Set cluster name in Cluster Autoscaler
kubectl set env deployment cluster-autoscaler \
  -n kube-system \
  -e CLUSTER_NAME=$CLUSTER_NAME

# Install External Secrets Operator
echo "📥 Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Create namespace if it doesn't exist
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -

# Create service account (will be annotated with IAM role later via create-iam-roles.sh)
kubectl create serviceaccount external-secrets \
  -n external-secrets-system \
  --dry-run=client -o yaml | kubectl apply -f -

helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --set installCRDs=true \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-secrets

# Wait for External Secrets Operator to be ready
echo "⏳ Waiting for External Secrets Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/external-secrets -n external-secrets-system || echo "⚠️  External Secrets Operator may still be starting..."

# Install Metrics Server (required for HPA)
echo "📥 Checking Metrics Server..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null; then
  echo "✅ Metrics Server already installed, skipping..."
else
  echo "📥 Installing Metrics Server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
fi

# Wait for metrics server to be ready
echo "⏳ Waiting for Metrics Server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

echo "✅ EKS cluster setup completed!"
echo ""
echo "Next steps:"
echo "1. Verify all pods are running: kubectl get pods -A"
echo "2. Create IAM roles and annotate service accounts: ./infrastructure/scripts/create-iam-roles.sh"
echo "3. Deploy MongoDB StatefulSet: kubectl apply -f k8s/mongodb/"
echo "4. Deploy microservices: kubectl apply -f k8s/base/"
echo "5. Configure Ingress: kubectl apply -f k8s/ingress/"




