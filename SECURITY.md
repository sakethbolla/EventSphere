# EventSphere Security Documentation

This document outlines all security measures, policies, and compliance configurations implemented in the EventSphere EKS deployment.

## Security Overview

EventSphere implements defense-in-depth security principles across all layers of the infrastructure and application stack.

## Image and Supply Chain Security

### Base Images

- **All Services**: Use `node:18-alpine` (minimal attack surface)
- **Frontend**: Uses `nginx:alpine` (lightweight, security-focused)
- **MongoDB**: Uses official `mongo:7.0` image
- **Regular Updates**: Base images are regularly updated to include security patches

### Image Security Practices

1. **Multi-stage Builds**: Reduce final image size and attack surface
2. **Non-root Users**: All containers run as non-root (UID 1001 for Node.js, UID 101 for Nginx)
3. **Minimal Dependencies**: Only production dependencies included in final images
4. **.dockerignore Files**: Prevent sensitive files from being included in images

### Image Scanning

- **ECR Scanning**: Automatic vulnerability scanning on push
- **Trivy Integration**: Scans in CI/CD pipeline before deployment
- **Policy**: Images with CRITICAL or HIGH vulnerabilities are blocked
- **Reports**: Scan results uploaded to GitHub Security tab

### Image Signing

- **Implementation**: Cosign v2.2.1 integrated in CI/CD pipeline
- **Signing Method**: Keyless signing using GitHub Actions OIDC tokens
- **Benefits**: No key management required, automatic signing, secure by default
- **Signing Process**: Images are automatically signed after successful build and push
- **Verification**: Signatures are verified before deployment in CI/CD pipeline
- **Failure Behavior**: Deployment is blocked if signature verification fails

#### Keyless Signing with OIDC

EventSphere uses **keyless signing** with Cosign, which eliminates the need for manual key management:

1. **How It Works:**
   - GitHub Actions workflows use OIDC tokens for authentication
   - Cosign signs images using ephemeral keys tied to the GitHub Actions run
   - Signatures are stored alongside images in container registries (GHCR/ECR)
   - Certificate includes GitHub Actions identity information

2. **Signing Process:**
   - Images are automatically signed after push to container registry
   - Signatures are stored as OCI artifacts alongside images
   - Works for both GHCR (GitHub Container Registry) and ECR (Amazon ECR)
   - All images are signed: auth-service, event-service, booking-service, frontend

3. **Verification Process:**
   - Signatures are verified before deployment in staging and production
   - Verification checks:
     - Signature exists and is valid
     - Certificate identity matches GitHub Actions issuer
     - Image hasn't been tampered with
   - **Deployment is blocked if verification fails** - ensures only signed images are deployed

4. **Workflow Integration:**
   - **PR Workflow** (`ci-pr.yml`): Signs images after build
   - **Main Branch** (`build.yml`): Signs images after build
   - **Staging Deployment** (`deploy-test.yml`): Verifies signatures before pulling
   - **Production Deployment** (`deploy.yml`): Verifies signatures before deploying

5. **Advantages of Keyless Signing:**
   - No key management overhead
   - No secrets to rotate
   - Automatic signing in CI/CD
   - Secure by default
   - Audit trail via GitHub Actions
   - No risk of key compromise

#### Manual Verification

You can manually verify image signatures:

```bash
# Verify GHCR image
cosign verify \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/OWNER/REPO/auth-service:TAG

# Verify ECR image
cosign verify \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ACCOUNT.dkr.ecr.REGION.amazonaws.com/auth-service:TAG
```

#### Migration from Key-Based Signing

If you previously used key-based signing and want to migrate:

1. **Old images** signed with keys will remain verifiable with the old public key
2. **New images** will use keyless signing automatically
3. **No action required** - the migration is automatic
4. For historical verification, keep the old public key available

## Cluster and Node Security

### EKS Cluster Security

- **Control Plane Logging**: All components enabled (API, Audit, Authenticator, Controller Manager, Scheduler)
- **Public API Endpoint**: Enabled with restricted CIDR (should be restricted in production)
- **Private API Endpoint**: Enabled for internal access
- **Version**: Kubernetes 1.28 (latest stable)

### Node Security

- **SSH Access**: Disabled on all worker nodes
- **Instance Types**: t3.medium (sufficient for workload, cost-effective)
- **AMI**: Amazon Linux 2 (regularly patched)
- **Volume Encryption**: All EBS volumes encrypted at rest

### IAM Roles for Service Accounts (IRSA)

- **Purpose**: Least-privilege access to AWS services
- **Implementation**: 
  - Notification Service: Access to SNS
  - External Secrets: Access to Secrets Manager
  - Fluent Bit: Access to CloudWatch Logs
  - ALB Controller: Access to ALB/NLB resources

### Security Groups

- **Node Security Groups**: Restrict inbound traffic to necessary ports only
- **ALB Security Groups**: Allow HTTPS (443) and HTTP (80) from internet
- **Database Security Groups**: Only allow connections from application pods

## Pod and Workload Security

### Pod Security Standards

- **Enforcement**: Restricted baseline policy
- **Namespace Labels**: Applied to prod namespace
  ```yaml
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/warn: restricted
  ```

### Security Context

All pods include:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001  # or 101 for nginx
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
```

### Container Security Context

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # Frontend only
  capabilities:
    drop:
    - ALL
```

### Resource Limits

- **CPU**: Requests and limits defined for all containers
- **Memory**: Requests and limits defined for all containers
- **Purpose**: Prevent resource exhaustion attacks

### Health Checks

- **Liveness Probes**: Detect and restart unhealthy containers
- **Readiness Probes**: Prevent traffic to unready pods
- **Startup Probes**: Allow slow-starting applications

### Policy Validation with Kyverno

Kubernetes manifests are validated against security policies using Kyverno before deployment:

- **Location**: `k8s/security/kyverno-policies.yaml`
- **Enforcement**: Policies are enforced in CI/CD pipeline before `kubectl apply`
- **Policies Enforced**:
  - Non-root user requirement (enforced)
  - Resource limits requirement (enforced)
  - Privilege escalation disabled (enforced)
  - Read-only root filesystem (audit mode)
  - Capability restrictions (audit mode)

**Validation Process:**
1. Kyverno CLI is installed in deployment workflows
2. All generated manifests are validated against policies
3. Deployment is blocked if validation fails
4. Only compliant manifests proceed to deployment

## Network Security

### Network Policies

Network policies enforce least-privilege communication:

1. **Frontend**: Can only communicate with backend services
2. **Auth Service**: Can communicate with MongoDB and receive requests from frontend/other services
3. **Event Service**: Can communicate with MongoDB and Auth Service
4. **Booking Service**: Can communicate with MongoDB, Auth Service, and Event Service
5. **MongoDB**: Only accepts connections from backend services

### TLS/HTTPS

- **External Traffic**: All external traffic encrypted with TLS 1.2+
- **Certificate Management**: AWS Certificate Manager (ACM)
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01
- **Internal Traffic**: Services communicate over HTTP within cluster (can be upgraded to mTLS with service mesh)

### Ingress Security

- **ALB**: Internet-facing with HTTPS only
- **WAF**: Recommended for production (commented in ingress config)
- **Path-based Routing**: Prevents unauthorized access to services

## Secrets Management

### External Secrets Operator

- **Purpose**: Integrate Kubernetes with AWS Secrets Manager
- **Implementation**: Secrets synced from AWS Secrets Manager to Kubernetes
- **Refresh Interval**: 1 hour
- **Secrets Managed**:
  - MongoDB credentials
  - JWT secret
  - SNS Topic ARNs

### Secret Storage

- **Never in Git**: All secrets stored in AWS Secrets Manager
- **Encryption**: Secrets encrypted at rest in AWS Secrets Manager
- **Access Control**: IRSA-based access (least privilege)
- **Rotation**: Manual rotation supported (automated rotation can be added)

### Kubernetes Secrets

- **Type**: Opaque
- **Creation**: Managed by External Secrets Operator
- **Access**: Only accessible by authorized service accounts

## Data Security

### Encryption at Rest

- **EBS Volumes**: Encrypted with AWS-managed keys
- **S3**: Encryption enabled (if used)
- **RDS**: Encryption enabled (if used)
- **Secrets Manager**: Encrypted by default

### Encryption in Transit

- **External**: TLS 1.2+ for all external traffic
- **Internal**: HTTP within cluster (can be upgraded to mTLS)
- **Database**: MongoDB connections can use TLS (recommended for production)

### Data Backup

- **MongoDB**: EBS snapshots (manual or automated via Velero)
- **Secrets**: Automatically backed up in AWS Secrets Manager
- **Configuration**: Version controlled in Git

## Monitoring and Detection

### GuardDuty

- **Status**: Enabled
- **Purpose**: Threat detection and monitoring
- **Findings**: Published to S3 and SNS
- **Integration**: Security Hub

### Security Hub

- **Status**: Enabled
- **Purpose**: Centralized security findings
- **Standards**: AWS Foundational Security Best Practices

### CloudWatch Logs

- **Purpose**: Centralized log aggregation
- **Retention**: 7 days
- **Encryption**: Encrypted at rest
- **Access**: IAM-based access control

### EKS Control Plane Logging

- **Components Logged**: API, Audit, Authenticator, Controller Manager, Scheduler
- **Destination**: CloudWatch Logs
- **Retention**: 7 days
- **Purpose**: Security auditing and compliance

## CI/CD Security

### GitHub Actions Security

- **Secrets**: Stored in GitHub Secrets (encrypted)
- **AWS Credentials**: Short-lived credentials via OIDC (recommended) or access keys
- **Branch Protection**: Required for main branch
- **PR Reviews**: Required before merge
- **Security Scans**: Automated in CI/CD pipeline

### Pipeline Security

1. **Build Stage**: 
   - Trivy scans all images
   - Blocks deployment on CRITICAL vulnerabilities
   - Reports uploaded to GitHub Security

2. **Deploy Stage**:
   - **Kyverno Policy Validation**: Validates Kubernetes manifests against security policies before deployment
     - Enforces non-root containers
     - Validates resource limits
     - Checks privilege escalation settings
     - Verifies security context configurations
   - Validates Kubernetes manifests
   - Checks for security misconfigurations
   - Automatic rollback on failure

3. **Security Scan Stage**:
   - Filesystem scans
   - Kubernetes manifest scans
   - Infrastructure scans (Checkov)

## Compliance and Auditing

### Audit Logging

- **EKS API**: All API calls logged
- **Authentication**: All authentication attempts logged
- **Access**: Audit logs stored in CloudWatch (7 days retention)

### Access Control

- **RBAC**: Kubernetes RBAC for cluster access
- **IAM**: AWS IAM for AWS resource access
- **Service Accounts**: Least-privilege service accounts
- **Network Policies**: Network-level access control

### Compliance Standards

- **Pod Security Standards**: Restricted baseline
- **CIS Benchmarks**: Aligned with CIS Kubernetes Benchmark
- **AWS Well-Architected**: Security pillar best practices

## Incident Response

### Security Incident Procedures

1. **Detection**: GuardDuty, Security Hub, Prometheus alerts
2. **Containment**: Network policies, pod security, resource limits
3. **Investigation**: CloudWatch logs, Prometheus metrics, pod logs
4. **Remediation**: Rollback deployments, update security policies
5. **Recovery**: Restore from backups, redeploy services

### Alerting

- **Critical Alerts**: Sent to SNS topic
- **Monitoring**: Prometheus + Alertmanager
- **Runbook**: Available in `monitoring/alertmanager/runbook.md`

## Security Best Practices Checklist

- [x] Non-root containers
- [x] Read-only root filesystems (where possible)
- [x] Resource limits defined
- [x] Health checks configured
- [x] Network policies enforced
- [x] Secrets not in Git
- [x] TLS for external traffic
- [x] Image scanning enabled
- [x] Image signing enabled (Cosign keyless signing)
- [x] Control plane logging enabled
- [x] GuardDuty enabled
- [x] Security Hub enabled
- [x] Pod Security Standards enforced
- [x] IRSA for AWS access
- [x] Least-privilege IAM policies
- [x] Encrypted volumes
- [x] Regular security scans

## Future Security Enhancements

- [x] Image signing with cosign (keyless signing)
- [x] Mandatory signature verification (blocks deployment if verification fails)
- [x] Kyverno policy validation in CI/CD pipeline
- [ ] Service Mesh (mTLS between services)
- [ ] Automated secret rotation
- [ ] WAF on ALB
- [ ] OPA Gatekeeper for runtime policy enforcement (in-cluster)
- [ ] Falco for runtime security
- [ ] Regular penetration testing
- [ ] Security training for team

## Security Contacts

For security issues, please contact:
- Security Team: security@enpm818rgroup7.work.gd
- DevOps Team: devops@enpm818rgroup7.work.gd

## References

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [AWS EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)

