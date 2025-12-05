# EventSphere Deployment Guide

This guide provides step-by-step instructions for deploying EventSphere to AWS EKS.

## Prerequisites

### Required Tools

- AWS CLI v2 installed and configured
- eksctl (latest version)
- kubectl (v1.28+)
- helm (v3.12+)
- Docker (for local testing)
- Git

### AWS Requirements

- AWS Account with appropriate permissions
- IAM user/role with permissions for:
  - EKS cluster creation
  - EC2 instance management
  - VPC and networking
  - IAM role creation
  - ECR repository creation
  - CloudWatch logs
  - GuardDuty
  - Security Hub

### AWS Account Setup

1. Configure AWS credentials:

   ```bash
   aws configure
   ```

2. Verify access:
   ```bash
   aws sts get-caller-identity
   ```

## Step 0: Easy deploy

Run the following scripts to setup EKS, build and push images, deploy services and ingress:

```bash
cd infrastructure
./scripts/setup-eks.sh
./scripts/build-and-push-images.sh
./scripts/process-templates.sh
./scripts/deploy-services.sh
```

After getting ALB address, update DNS records so the domain points to ALB

## Step 1: Create EKS Cluster

### 1.1 Review Cluster Configuration

Review and update `infrastructure/eksctl-cluster.yaml`:

- Update region if needed
- Adjust node instance types if needed
- Update tags

### 1.2 Create Cluster

```bash
cd infrastructure
chmod +x scripts/setup-eks.sh
./scripts/setup-eks.sh
```

This script will:

- Create the EKS cluster
- Set up node groups
- Install required add-ons (ALB Controller, Cluster Autoscaler, etc.)
- Configure kubeconfig

### 1.3 Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

You should see at least 3 nodes across multiple availability zones.

## Step 2: Image Signing and Verification (Automatic)

### 2.1 Automatic Keyless Signing

EventSphere uses **keyless signing** with Cosign, which means:

- **No setup required** - signing happens automatically in CI/CD
- **No key management** - uses GitHub Actions OIDC tokens
- **Secure by default** - all images are automatically signed
- **Verification enforced** - deployments verify signatures before pulling images

### How It Works

1. **Automatic Signing:**
   - Images are built, pushed to ECR, then automatically signed in CI/CD pipeline
   - Uses Cosign v2.2.1 with GitHub Actions OIDC authentication
   - Signatures stored alongside images in ECR

2. **Automatic Verification:**
   - Signatures are verified before deployment in the CD pipeline
   - **Deployment is blocked if signature verification fails**
   - Ensures only signed, untampered images are deployed
   - Verification happens automatically in the deploy job

3. **No Manual Steps Required:**
   - No keys to generate or manage
   - No secrets to configure
   - Works automatically in all workflows

### Manual Verification (Optional)

If you want to manually verify image signatures locally:

```bash
# Install cosign
# macOS
brew install cosign

# Linux
wget https://github.com/sigstore/cosign/releases/download/v2.2.1/cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT.dkr.ecr.REGION.amazonaws.com

# Verify ECR image
cosign verify \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ACCOUNT.dkr.ecr.REGION.amazonaws.com/auth-service:TAG
```

**Note**: Image signing and verification are fully automated in CI/CD - no manual configuration needed!

## Step 3: Set Up ECR Repositories

**Note**: If you plan to use the automated build script in Step 4.1, you can skip this step as the script will create ECR repositories automatically.

### 3.1 Create ECR Repositories

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

for repo in auth-service event-service booking-service frontend; do
  aws ecr create-repository \
    --repository-name $repo \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256
done
```

### 3.2 Login to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

## Step 4: Build and Push Docker Images

### 4.1 Automated Build and Push (Recommended)

Use the provided script to automatically build and push all Docker images to ECR:

```bash
cd infrastructure/scripts
chmod +x build-and-push-images.sh
./build-and-push-images.sh
```

The script will:

- Create ECR repositories if they don't exist (with image scanning and encryption)
- Log into ECR automatically
- Build Docker images for all services (auth-service, event-service, booking-service, frontend)
- Tag images with the correct ECR registry URL
- Push all images to ECR

**Options:**

```bash
# Use custom tag
./build-and-push-images.sh --tag v1.0.0

# Use custom region
./build-and-push-images.sh --region us-west-2

# Skip building (only push existing images)
./build-and-push-images.sh --skip-build

# Skip ECR repository creation
./build-and-push-images.sh --skip-repo-creation

# Show help
./build-and-push-images.sh --help
```

**Environment Variables:**

- `AWS_REGION` - AWS region (default: us-east-1)
- `IMAGE_TAG` - Image tag (default: latest)
- `SKIP_BUILD` - Skip building (default: false)
- `SKIP_REPO_CREATION` - Skip ECR repo creation (default: false)

### 4.2 Manual Build and Push (Alternative)

If you prefer to build and push manually:

#### 4.2.1 Build Images Locally

```bash
# Build all services
docker build -t auth-service:latest services/auth-service/
docker build -t event-service:latest services/event-service/
docker build -t booking-service:latest services/booking-service/
docker build -t frontend:latest frontend/
```

#### 4.2.2 Tag and Push to ECR

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push each service
for service in auth-service event-service booking-service frontend; do
  docker tag $service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$service:latest
done
```

**Note**: In production, use GitHub Actions workflows for automated builds, signing, and deployment with automatic rollback.

## Step 5: Process Configuration Templates

Before deploying to Kubernetes, you need to process template files with your AWS account configuration. This step uses environment variable substitution to generate deployment-ready manifests.

### 5.1 Create Configuration File

Create your configuration file from the example:

```bash
cd infrastructure/config
cp config.env.example config.env
```

Edit `config.env` and set your values:

```bash
# AWS Configuration
# Leave empty to auto-detect from AWS CLI (recommended if AWS CLI is configured)
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"

# AWS Region
export AWS_REGION="${AWS_REGION:-us-east-1}"

# ACM Certificate ARN for HTTPS/TLS
# Get this from: aws acm list-certificates --region us-east-1
export ACM_CERTIFICATE_ARN="${ACM_CERTIFICATE_ARN:-arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/...}"

# Cluster name
export CLUSTER_NAME="${CLUSTER_NAME:-eventsphere-cluster}"
```

**Important Configuration Notes:**

1. **AWS_ACCOUNT_ID Auto-Detection**:
   - If `AWS_ACCOUNT_ID` is left empty (default), the `process-templates.sh` script will automatically detect it using `aws sts get-caller-identity`
   - This requires AWS CLI to be installed and configured with valid credentials
   - If auto-detection fails, you must manually set `AWS_ACCOUNT_ID`

2. **ECR_REGISTRY Calculation**:
   - `ECR_REGISTRY` is automatically calculated as `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com`
   - This happens **after** `AWS_ACCOUNT_ID` is detected/set, ensuring the registry URL includes the account ID
   - The script automatically fixes invalid `ECR_REGISTRY` values (e.g., `.dkr.ecr.us-east-1.amazonaws.com`)

3. **IAM Role ARNs**:
   - Automatically calculated from `AWS_ACCOUNT_ID` if not explicitly set:
     - `FLUENT_BIT_ROLE_ARN`: `arn:aws:iam::${AWS_ACCOUNT_ID}:role/fluent-bit-role`
     - `EXTERNAL_SECRETS_ROLE_ARN`: `arn:aws:iam::${AWS_ACCOUNT_ID}:role/external-secrets-role`

4. **ACM Certificate ARN**:
   - Required for HTTPS/TLS termination on the ALB
   - Find your certificate ARN: `aws acm list-certificates --region us-east-1`
   - The certificate must be in the same region as your EKS cluster

### 5.2 Process Templates (Recommended)

Use the template processing script to generate deployment-ready manifests:

```bash
cd infrastructure/scripts
chmod +x process-templates.sh
./process-templates.sh
```

The script will:

- Load configuration from `infrastructure/config/config.env`
- Auto-detect AWS Account ID from AWS CLI if not set in config
- **Fix invalid ECR_REGISTRY values** if detected (prevents InvalidImageName errors)
- Process all `.template` files using environment variable substitution
- Generate processed files in `k8s/generated/` directory
- Copy non-template files to the generated directory

**Verification After Processing:**

Always verify the output configuration:

```bash
# Check the script output shows correct values:
# ✅ Detected AWS Account ID: 123456789012
# ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

Then verify generated manifests:

```bash
# Check image references in generated deployments
grep -r "image:" k8s/generated/base/*.yaml

# Should show valid image URLs with account ID:
# image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

# If you see invalid URLs like:
# image: .dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
# Then AWS_ACCOUNT_ID was not set correctly
```

**Troubleshooting Template Processing:**

If you encounter issues:

1. **Invalid ECR_REGISTRY in output**:

   ```bash
   # Verify AWS CLI is configured
   aws sts get-caller-identity

   # If that fails, manually set AWS_ACCOUNT_ID in config.env
   export AWS_ACCOUNT_ID="123456789012"
   ```

2. **ECR_REGISTRY shows as `.dkr.ecr...`**:
   - The script should auto-fix this, but if it doesn't:
   - Manually set `AWS_ACCOUNT_ID` in `config.env`
   - Remove any manually set `ECR_REGISTRY` line (let it auto-calculate)
   - Re-run `process-templates.sh`

3. **Template processing fails**:
   ```bash
   # Ensure envsubst is installed
   # macOS: brew install gettext
   # Linux: sudo apt-get install gettext-base
   ```

**Generated files structure:**

```
k8s/generated/
├── base/
│   ├── auth-service-deployment.yaml
│   ├── event-service-deployment.yaml
│   ├── booking-service-deployment.yaml
│   ├── frontend-deployment.yaml
│   └── ... (other base files)
├── ingress/
│   └── ingress.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── staging/
        └── kustomization.yaml
```

### 5.3 Manual Processing (Alternative)

If you prefer to process templates manually using environment variables:

```bash
# Set environment variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export ACM_CERTIFICATE_ARN="arn:aws:acm:us-east-1:${AWS_ACCOUNT_ID}:certificate/..."
export FLUENT_BIT_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/fluent-bit-role"
export CLUSTER_NAME="eventsphere-cluster"

# Process a template file
envsubst < k8s/ingress/ingress.yaml.template > k8s/generated/ingress/ingress.yaml
```

**Note**: In CI/CD pipelines, this is done automatically by the deploy workflow using the `process-templates.sh` script.

## Step 6: Configure AWS Secrets Manager

### 6.1 Automated Deployment (Recommended)

Use the comprehensive deployment script to automate Steps 6-9:

```bash
cd infrastructure/scripts
chmod +x deploy-services.sh
./deploy-services.sh
```

This script will:

- Create secrets in AWS Secrets Manager (with auto-generated secure passwords)
- Create IAM roles for service accounts
- Deploy MongoDB
- Deploy all microservices

**Options:**

```bash
# Skip specific steps
./deploy-services.sh --skip-secrets    # Skip AWS Secrets Manager
./deploy-services.sh --skip-iam       # Skip IAM role creation
./deploy-services.sh --skip-mongodb   # Skip MongoDB deployment
./deploy-services.sh --skip-services  # Skip microservices deployment

# Use External Secrets Operator
./deploy-services.sh --use-external-secrets

# Custom passwords
./deploy-services.sh --mongodb-password "YOUR_PASSWORD" --jwt-secret "YOUR_JWT_SECRET"

# Dry run (see what would be done)
./deploy-services.sh --dry-run
```

### 6.2 Manual Secret Creation

If you prefer to create secrets manually:

```bash
# MongoDB credentials
aws secretsmanager create-secret \
  --name eventsphere/mongodb \
  --secret-string '{"username":"admin","password":"CHANGE_ME_SECURE_PASSWORD","connection-string":"mongodb://admin:CHANGE_ME_SECURE_PASSWORD@mongodb.prod.svc.cluster.local:27017/eventsphere?authSource=admin"}' \
  --region us-east-1

# JWT Secret
aws secretsmanager create-secret \
  --name eventsphere/auth-service \
  --secret-string '{"jwt-secret":"CHANGE_ME_JWT_SECRET_KEY"}' \
  --region us-east-1
```

### 6.3 Update External Secrets

If using External Secrets Operator, ensure `k8s/security/external-secrets.yaml` is configured with correct secret names and keys.

## Step 7: Create IAM Roles for Service Accounts

### 7.1 Automatic Creation (Recommended)

The `deploy-services.sh` script (Step 6.1) automatically creates IAM roles and annotates service accounts. Alternatively, use the dedicated script:

```bash
cd infrastructure/scripts
chmod +x create-iam-roles.sh
./create-iam-roles.sh
```

This script creates:

- Fluent Bit Role (CloudWatch Logs access)
- External Secrets Operator Role (Secrets Manager access)

**Note**: The `deploy-services.sh` script automatically annotates service accounts with the created role ARNs.

### 7.2 Manual Creation

See `infrastructure/iam-roles.yaml` for detailed instructions on manual role creation.

### 7.3 Annotate Service Accounts

If not using `deploy-services.sh`, manually annotate service accounts:

```bash
# Fluent Bit
kubectl annotate serviceaccount fluent-bit -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/fluent-bit-role

# External Secrets
kubectl annotate serviceaccount external-secrets -n external-secrets-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/external-secrets-role
```

**Note**: ALB Controller, Cluster Autoscaler, EBS CSI, and EFS CSI roles are created automatically by eksctl.

## Step 8: Deploy MongoDB

### 8.1 Automated Deployment (Recommended)

The `deploy-services.sh` script (Step 6.1) automatically deploys MongoDB. It will:

- Create namespaces
- Create storage class
- Create Kubernetes secrets (or use External Secrets)
- Deploy MongoDB StatefulSet
- Wait for MongoDB to be ready
- Verify the deployment

### 8.2 Manual Deployment

If deploying manually:

```bash
# Create namespaces
kubectl apply -f k8s/base/namespaces.yaml

# Create storage class
kubectl apply -f k8s/mongodb/storageclass.yaml

# Create MongoDB secret (if not using External Secrets)
kubectl create secret generic mongodb-secret \
  --from-literal=username=admin \
  --from-literal=password=CHANGE_ME_SECURE_PASSWORD \
  --from-literal=connection-string="mongodb://admin:CHANGE_ME_SECURE_PASSWORD@mongodb.prod.svc.cluster.local:27017/eventsphere?authSource=admin" \
  -n prod

# Create auth service secret
kubectl create secret generic auth-service-secret \
  --from-literal=jwt-secret=CHANGE_ME_SECURE_PASSWORD \
  -n prod

# Deploy MongoDB
kubectl apply -f k8s/mongodb/

# Verify MongoDB
kubectl get pods -n prod -l app=mongodb
kubectl get pvc -n prod
```

Wait for MongoDB pod to be in `Running` state.

## Step 9: Deploy Microservices

### 9.1 Automated Deployment (Recommended)

The `deploy-services.sh` script (Step 6.1) automatically deploys all microservices. It will:

- Verify templates are processed
- Apply ConfigMaps
- Apply RBAC
- Apply Deployments and Services
- Apply HPA configurations
- Wait for deployments to be ready
- Verify all pods are running

**Note**: For production deployments via CI/CD, Helm is used with `--atomic` flag for automatic rollback on failure.

### 9.2 Manual Deployment

If deploying manually:

```bash
# Ensure templates are processed first
cd infrastructure/scripts
./process-templates.sh

# Apply ConfigMaps
kubectl apply -f k8s/generated/base/configmaps.yaml

# Apply RBAC
kubectl apply -f k8s/generated/base/rbac.yaml

# Apply Deployments and Services
kubectl apply -f k8s/generated/base/

# Apply HPA
kubectl apply -f k8s/hpa/
```

### 9.3 Verify Deployments

```bash
kubectl get deployments -n prod
kubectl get pods -n prod
kubectl get services -n prod
```

All pods should be in `Running` state and services should have endpoints.

### 9.4 Verify RBAC Configuration

The RBAC configuration provides least-privilege access control across all environments.

```bash
# Verify service accounts are created
kubectl get serviceaccounts -n prod
kubectl get serviceaccounts -n staging
kubectl get serviceaccounts -n dev

# Verify roles are created
kubectl get roles -n prod
kubectl get roles -n staging
kubectl get roles -n dev

# Verify cluster roles
kubectl get clusterroles | grep eventsphere

# Test service account permissions (example: auth-service)
kubectl auth can-i get secret/mongodb-secret \
  --as=system:serviceaccount:prod:auth-service-sa -n prod
```

**RBAC Features:**

- Service accounts for all microservices (dev, staging, prod)
- Least-privilege roles for each service
- User roles: Developer (read-only prod), Operator (full access), Admin
- Namespace isolation with different access levels

**To add human users to the cluster**, see `k8s/base/RBAC_README.md` for detailed instructions.

## Step 10: Configure Ingress

### 10.1 Create ACM Certificate

```bash
# Request certificate (replace domain with your domain)
aws acm request-certificate \
  --domain-name enpm818rgroup7.work.gd \
  --subject-alternative-names api.enpm818rgroup7.work.gd \
  --validation-method DNS \
  --region us-east-1
```

Follow DNS validation instructions to validate the certificate.

### 10.2 Deploy Ingress

Deploy the processed ingress configuration:

```bash
kubectl apply -f k8s/generated/ingress/
```

**Note**: The ingress template is automatically processed in Step 5. If you need to update the certificate ARN, update `config.env` and re-run `process-templates.sh`.

### 10.4 Get ALB Address

```bash
kubectl get ingress -n prod
```

Note the ADDRESS field - this is your ALB DNS name.

### 10.5 Update DNS

Create DNS records pointing to the ALB:

- `enpm818rgroup7.work.gd` → ALB address
- `api.enpm818rgroup7.work.gd` → ALB address

## Step 11: Deploy Monitoring

### 11.1 Add Prometheus Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 11.2 Deploy Prometheus Stack

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f monitoring/prometheus/values.yaml
```

### 11.3 Deploy Alert Rules

```bash
kubectl apply -f monitoring/prometheus/alert-rules.yaml
```

### 11.4 Access Grafana

```bash
# Get Grafana admin password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access Grafana
kubectl port-forward --namespace monitoring svc/prometheus-grafana 3000:80
```

Access Grafana at `http://localhost:3000` (admin / password from above)

### 11.5 Deploy CloudWatch Logging

```bash
# Deploy processed fluent-bit configuration
kubectl apply -f monitoring/cloudwatch/generated/fluent-bit-config.yaml
```

**Note**: The fluent-bit configuration template is automatically processed in Step 5 with the correct IAM role ARN.

## Step 12: Configure Security

### 12.1 Deploy Network Policies

```bash
kubectl apply -f k8s/security/network-policies.yaml
```

### 12.2 Deploy Pod Security Standards

```bash
kubectl apply -f k8s/security/pod-security-policy.yaml
```

### 12.3 Enable GuardDuty and Logging

```bash
cd infrastructure/scripts
chmod +x enable-security.sh
./enable-security.sh
```

## Step 13: Verify Deployment

### 13.1 Check All Resources

```bash
kubectl get all -n prod
kubectl get ingress -n prod
kubectl get hpa -n prod
kubectl get networkpolicies -n prod
```

### 13.2 Test Services

```bash
# Test health endpoints
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://auth-service.prod.svc.cluster.local:4001/health

# Test from within cluster
kubectl exec -it -n prod <pod-name> -- wget -O- http://auth-service:4001/health
```

### 13.3 Test External Access

```bash
# Test frontend
curl https://enpm818rgroup7.work.gd

# Test API
curl https://api.enpm818rgroup7.work.gd/api/events
```

## Troubleshooting

### EKS Cluster Creation Issues

1. **eksctl cluster creation fails:**

   ```bash
   # Check eksctl version
   eksctl version

   # Verify AWS credentials
   aws sts get-caller-identity

   # Check for existing cluster
   eksctl get cluster --region us-east-1

   # Review cluster configuration
   cat infrastructure/eksctl-cluster.yaml
   ```

2. **Node groups not scaling:**

   ```bash
   # Check Cluster Autoscaler logs
   kubectl logs -n kube-system deployment/cluster-autoscaler

   # Verify node group configuration
   eksctl get nodegroup --cluster eventsphere-cluster --region us-east-1
   ```

3. **OIDC provider not found:**

   ```bash
   # Create OIDC provider manually
   eksctl utils associate-iam-oidc-provider --cluster eventsphere-cluster --region us-east-1 --approve
   ```

4. **VPC/subnet issues:**

   ```bash
   # Check VPC configuration
   aws eks describe-cluster --name eventsphere-cluster --region us-east-1 \
     --query 'cluster.resourcesVpcConfig'

   # Verify subnets exist
   aws ec2 describe-subnets --filters "Name=tag:Name,Values=*eventsphere*" --region us-east-1
   ```

### Pods Not Starting

1. Check pod logs:

   ```bash
   kubectl logs -n prod <pod-name>
   ```

2. Check pod events:

   ```bash
   kubectl describe pod -n prod <pod-name>
   ```

3. Check resource limits:
   ```bash
   kubectl top pods -n prod
   ```

### Services Not Accessible

1. Check service endpoints:

   ```bash
   kubectl get endpoints -n prod
   ```

2. Check ingress:

   ```bash
   kubectl describe ingress -n prod
   ```

3. Check ALB in AWS Console

### MongoDB Connection Issues

1. Check MongoDB pod:

   ```bash
   kubectl get pods -n prod -l app=mongodb
   kubectl logs -n prod -l app=mongodb
   ```

2. Test connection:
   ```bash
   kubectl exec -it -n prod <mongodb-pod> -- mongosh --eval "db.adminCommand('ping')"
   ```

### Image Pull Errors

1. Verify ECR access:

   ```bash
   aws ecr describe-repositories
   ```

2. Check image pull secrets:

   ```bash
   kubectl get secrets -n prod
   ```

3. Verify IAM roles for nodes have ECR read permissions

4. **Common Issue: InvalidImageName Error**:

   If pods show `InvalidImageName` error with image like `.dkr.ecr.us-east-1.amazonaws.com/service:latest`:

   **Root Cause**: The deployment manifest has an invalid ECR registry URL missing the AWS Account ID.

   **Diagnosis**:

   ```bash
   # Check deployment image reference
   kubectl get deployment auth-service -n prod -o yaml | grep image:

   # If it shows: image: .dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
   # Then the template was processed incorrectly
   ```

   **Solution**:

   ```bash
   # 1. Verify config.env has AWS_ACCOUNT_ID set or AWS CLI configured
   cat infrastructure/config/config.env | grep AWS_ACCOUNT_ID

   # 2. Re-process templates
   cd infrastructure/scripts
   ./process-templates.sh

   # 3. Verify generated manifests have correct image URLs
   grep "image:" k8s/generated/base/auth-service-deployment.yaml
   # Should show: image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest

   # 4. Re-apply deployment
   kubectl apply -f k8s/generated/base/auth-service-deployment.yaml -n prod

   # 5. Verify pod is now starting correctly
   kubectl get pods -n prod -l app=auth-service
   ```

## Cleanup

To tear down the entire cluster:

```bash
cd infrastructure/scripts
chmod +x teardown-eks.sh
./teardown-eks.sh
```

**Warning**: This will delete the entire cluster and all resources!
