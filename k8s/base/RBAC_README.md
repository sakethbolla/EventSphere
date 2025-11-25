# EventSphere RBAC Configuration

This document explains the Role-Based Access Control (RBAC) configuration for EventSphere's Kubernetes deployment across dev, staging, and production environments.

## Overview

The RBAC configuration implements **least-privilege access control** with three layers:

1. **Service Accounts**: For microservices to access Kubernetes resources
2. **Service Roles**: Minimal permissions for each service to function
3. **User Roles**: Human access patterns for developers, operators, and admins

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RBAC Hierarchy                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ClusterRoles (Cross-namespace)                            │
│  ├── eventsphere-developer     (View cluster resources)    │
│  ├── eventsphere-operator      (Manage cluster resources)  │
│  └── eventsphere-admin         (Full cluster access)       │
│                                                             │
│  Namespace Roles (Per environment)                         │
│  ├── dev                                                    │
│  │   ├── developer-full-access       (Edit everything)     │
│  │   ├── operator-full-access        (Admin access)        │
│  │   └── Service-specific roles      (Minimal perms)       │
│  ├── staging                                                │
│  │   ├── developer-full-access       (Edit everything)     │
│  │   ├── operator-full-access        (Admin access)        │
│  │   └── Service-specific roles      (Minimal perms)       │
│  └── prod                                                   │
│      ├── developer-read-only         (View only)           │
│      ├── operator-full-access        (Admin access)        │
│      └── Service-specific roles      (Minimal perms)       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Service Accounts

### Production Namespace
- `auth-service-sa` - Authentication service
- `event-service-sa` - Event management service
- `booking-service-sa` - Booking service
- `frontend-sa` - Frontend application

### Staging Namespace
- Same service accounts as production

### Development Namespace
- Same service accounts as production

## Service-Specific Roles

Each microservice has a dedicated role with **minimal permissions**:

### Auth Service
**Permissions (Production):**
- Read ConfigMaps
- Read specific secrets: `mongodb-secret`, `jwt-secret`

**Rationale:** Needs database credentials and JWT secret for authentication

### Event Service
**Permissions (Production):**
- Read ConfigMaps
- Read specific secret: `mongodb-secret`

**Rationale:** Needs database credentials only

### Booking Service
**Permissions (Production):**
- Read ConfigMaps
- Read specific secret: `mongodb-secret`

**Rationale:** Needs database credentials only

### Frontend
**Permissions (All Environments):**
- Read ConfigMaps only

**Rationale:** Frontend is stateless and only needs configuration

### Dev/Staging Environments
Services in dev/staging have slightly broader permissions (all secrets) to facilitate debugging and development.

## User Roles

### 1. Developer Role (`eventsphere-developer`)

**Cluster-level Permissions:**
- View nodes and namespaces
- View persistent volumes

**Namespace-level Permissions:**
- **Dev**: Full edit access (create, update, delete resources)
- **Staging**: Full edit access
- **Production**: **Read-only** access (view resources, logs)

**Use Case:** Software engineers developing and testing features

### 2. Operator Role (`eventsphere-operator`)

**Cluster-level Permissions:**
- View and manage nodes
- View persistent volumes and storage classes
- View component statuses

**Namespace-level Permissions:**
- **Dev**: Full admin access
- **Staging**: Full admin access
- **Production**: Full admin access

**Use Case:** DevOps engineers managing deployments and infrastructure

### 3. Admin Role (`eventsphere-admin`)

**Permissions:**
- Full cluster access (all resources, all verbs)

**Use Case:** Cluster administrators only (emergency access)

## Applying RBAC Configuration

### 1. Deploy Service Accounts and Roles

```bash
# Apply RBAC configuration
kubectl apply -f k8s/base/rbac.yaml

# Verify service accounts
kubectl get serviceaccounts -n prod
kubectl get serviceaccounts -n staging
kubectl get serviceaccounts -n dev

# Verify roles
kubectl get roles -n prod
kubectl get roles -n staging
kubectl get roles -n dev

# Verify cluster roles
kubectl get clusterroles | grep eventsphere
```

### 2. Bind Users to Roles

Edit the bottom of `rbac.yaml` and uncomment the example user bindings, replacing placeholders with actual user identities.

#### Option A: AWS IAM Users

For AWS IAM users, use the IAM user ARN:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-jane-doe
subjects:
- kind: User
  name: arn:aws:iam::123456789012:user/jane.doe
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: eventsphere-developer
  apiGroup: rbac.authorization.k8s.io
```

#### Option B: OIDC Groups (Recommended)

If using OIDC (Google Workspace, Okta, etc.):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-group
subjects:
- kind: Group
  name: developers@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: eventsphere-developer
  apiGroup: rbac.authorization.k8s.io
```

### 3. Configure AWS IAM Identity Mapping

For AWS IAM users to access EKS, add them to the aws-auth ConfigMap:

```bash
kubectl edit configmap aws-auth -n kube-system
```

Add:
```yaml
mapUsers: |
  - userarn: arn:aws:iam::123456789012:user/jane.doe
    username: jane.doe
    groups:
      - eventsphere:developers
  - userarn: arn:aws:iam::123456789012:user/john.smith
    username: john.smith
    groups:
      - eventsphere:operators
```

## Testing RBAC

### Test Service Account Permissions

```bash
# Test auth-service can read mongodb-secret
kubectl auth can-i get secret/mongodb-secret \
  --as=system:serviceaccount:prod:auth-service-sa -n prod

# Test auth-service CANNOT read other secrets
kubectl auth can-i get secret/some-other-secret \
  --as=system:serviceaccount:prod:auth-service-sa -n prod
```

### Test User Permissions

```bash
# Test developer can edit in dev
kubectl auth can-i create deployment \
  --as=jane.doe@example.com -n dev

# Test developer can only view in prod
kubectl auth can-i create deployment \
  --as=jane.doe@example.com -n prod

# Test operator can edit in prod
kubectl auth can-i create deployment \
  --as=john.smith@example.com -n prod
```

### Impersonate Users for Testing

```bash
# Impersonate developer in prod (should fail)
kubectl --as=jane.doe@example.com create deployment test \
  --image=nginx -n prod

# Impersonate developer in dev (should succeed)
kubectl --as=jane.doe@example.com create deployment test \
  --image=nginx -n dev
```

## Common RBAC Tasks

### Grant Developer Access to New User

1. Add user to aws-auth ConfigMap (see above)
2. Create bindings:

```yaml
# Save as user-binding.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-alice
subjects:
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: eventsphere-developer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-alice-dev
  namespace: dev
subjects:
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-full-access
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-alice-staging
  namespace: staging
subjects:
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-full-access
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-alice-prod
  namespace: prod
subjects:
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-read-only
  apiGroup: rbac.authorization.k8s.io
```

Apply:
```bash
kubectl apply -f user-binding.yaml
```

### Revoke User Access

```bash
# Delete all bindings for a user
kubectl delete clusterrolebinding developer-alice
kubectl delete rolebinding developer-alice-dev -n dev
kubectl delete rolebinding developer-alice-staging -n staging
kubectl delete rolebinding developer-alice-prod -n prod
```

### Grant Temporary Admin Access

```bash
# Create temporary admin binding
kubectl create clusterrolebinding temp-admin-alice \
  --clusterrole=cluster-admin \
  --user=alice@example.com

# Revoke after task completion
kubectl delete clusterrolebinding temp-admin-alice
```

## Troubleshooting

### User Can't Access Cluster

1. Check if user is in aws-auth:
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

2. Check if ClusterRoleBinding exists:
```bash
kubectl get clusterrolebinding | grep <username>
```

3. Verify user identity:
```bash
kubectl auth whoami
```

### Service Can't Access Resources

1. Check if service account exists:
```bash
kubectl get serviceaccount <sa-name> -n <namespace>
```

2. Check role binding:
```bash
kubectl get rolebinding -n <namespace> | grep <sa-name>
```

3. Test permissions:
```bash
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

### Permission Denied Errors

Check current user permissions:
```bash
# List all permissions for current user
kubectl auth can-i --list --namespace=prod

# Check specific permission
kubectl auth can-i create deployment -n prod
```

## Security Best Practices

1. **Principle of Least Privilege**: Services only get permissions they absolutely need
2. **Production Read-Only**: Developers have read-only access to production
3. **Namespace Isolation**: Resources are isolated by namespace
4. **Named Secrets**: Production roles reference specific secret names (not wildcards)
5. **Audit Logs**: Enable EKS audit logging to track RBAC changes
6. **Regular Reviews**: Periodically review and audit role assignments
7. **Service Account Tokens**: Use projected service account tokens with time limits
8. **Emergency Access**: Use admin role sparingly and with audit trail

## Compliance Notes

This RBAC configuration satisfies the following security requirements:

- ✅ **Least-privilege access**: Each service has minimal permissions
- ✅ **Multi-environment separation**: Dev/staging/prod have different access levels
- ✅ **IRSA integration**: Service accounts use IAM roles for AWS access
- ✅ **Audit trail**: All actions are logged through EKS control plane logs
- ✅ **Defense in depth**: Combined with Network Policies for additional security

## References

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [AWS EKS IAM Integration](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Security Best Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)

