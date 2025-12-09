# EventSphere

EventSphere is a microservice-based event management platform. The repository contains the backend services, a React frontend, and shared application code.
<img width="2557" height="1266" alt="image" src="https://github.com/user-attachments/assets/2879f378-bc57-4968-a198-7bd4bf08bcbf" />

## Features

- User authentication with JWT-based sessions
- Event browsing, search, and category filtering
- Ticket booking workflow with simulated payments
- Booking management including history and cancellations
- Administrative tooling for event creation and analytics
- Email notifications via AWS SNS for user registration and booking confirmations

## Service Overview

The system is composed of the following independently running services:

- **Auth Service** (port 4001) – manages user accounts and tokens
- **Event Service** (port 4002) – handles CRUD operations for events
- **Booking Service** (port 4003) – coordinates ticket reservations
- **Notification Service** (port 4004) – sends email notifications via AWS SNS
- **Frontend** (port 3000) – React single-page application that consumes the APIs above

All services communicate over HTTP and store data in MongoDB. Ensure that a MongoDB instance is running locally and that each service's `.env` file points to it.

> Note: Ready-to-use `.env` files are committed with non-sensitive development defaults (local MongoDB URLs, service ports, and JWT secret). You can start the stack immediately and tailor the values later if needed.

## Project Structure

```
EventSphere/
├── frontend/                    # React frontend application
├── services/                    # Microservices
│   ├── auth-service/
│   ├── event-service/
│   ├── booking-service/
│   └── notification-service/
├── k8s/                         # Kubernetes manifests
│   ├── base/                    # Base configurations
│   ├── mongodb/                 # MongoDB StatefulSet
│   ├── ingress/                 # ALB Ingress config
│   ├── security/                # Security policies
│   ├── hpa/                     # Horizontal Pod Autoscaling
│   └── overlays/                # Environment-specific configs
├── infrastructure/              # Infrastructure as Code
│   ├── eksctl-cluster.yaml      # EKS cluster config
│   └── scripts/                 # Setup/teardown scripts
├── monitoring/                  # Observability configs
│   ├── prometheus/              # Prometheus setup
│   ├── grafana/                 # Grafana dashboards
│   └── cloudwatch/              # CloudWatch logging
├── .github/                     # CI/CD workflows
│   └── workflows/               # GitHub Actions
│       ├── ci.yml               # CI pipeline (Code Quality, K8s Validation, Security Scans)
│       └── cd.yml               # CD pipeline (Build, Push, Sign, Deploy to EKS)
│   ├── CODEOWNERS               # Defines codeowners
│   └── PULL_REQUEST_TEMPLATE.md # Template for PR Descriptions
└── README.md
```

## Getting Started

### Prerequisites

- Node.js 25.1.0 or later
- npm (ships with Node.js)
- MongoDB running locally on the default port or accessible connection string

### Install Dependencies

Install dependencies for each service and the frontend:

```bash
cd services/auth-service; npm install
cd ../event-service; npm install
cd ../booking-service; npm install
cd ../notification-service; npm install
cd ../../frontend; npm install
```

### Set up Pre-commit Hooks (Recommended)

Pre-commit hooks automatically lint and format your code before commits:

```bash
# Install pre-commit (requires Python)
pip install pre-commit
# or
brew install pre-commit  # macOS

# Install the git hooks
pre-commit install

# Test the hooks (optional)
pre-commit run --all-files
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

### Run the Backend Services

Each backend service exposes an npm script for development mode with automatic reloads. Run each one in a separate terminal window:

```bash
cd services/auth-service; npm run dev
cd services/event-service; npm run dev
cd services/booking-service; npm run dev
cd services/notification-service; npm run dev
```

**Note:** The notification service requires AWS SNS configuration. See [Notification Service Setup](#notification-service-setup) below.

### Run the Frontend

```bash
cd frontend
npm start
```

The React development server will proxy API requests to the backend services when they are running on the ports listed above.

## Using EventSphere

### Account types and sign-in flow

- **Attendee accounts** are created through the public registration form available from the navbar. Newly registered users default to the `user` role and can browse events, reserve seats, and review their bookings.
- **Administrator accounts** can create, edit, and delete events. Because the public registration screen hides administrative privileges, you must explicitly set the `role` field when creating an admin profile.

### Creating an administrator

1. Start the authentication service and connect to the MongoDB instance defined in `services/auth-service/.env`.
2. Issue a POST request directly to the auth-service endpoint and include `"role": "admin"` in the payload. Example using `curl` while the auth service is running on port 4001:
   ```bash
   curl -X POST http://localhost:4001/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Event Manager",
       "email": "admin@example.com",
       "password": "supersecure",
       "role": "admin"
     }'
   ```
3. The response contains a JWT and the user object. Store the token (the frontend writes it to `localStorage`) and log in through the UI using the same credentials.

> Note: Already registered users can also be promoted by updating the `role` field to `admin` directly in MongoDB.

### Managing events as an admin

1. Log in with an administrator account. The navbar reveals a **Manage Events** link that routes to `/admin/events`.
2. Use the **Create Event** button to open the event form. Fill in title, description, category, venue, date, time, capacity, price, organizer, and an optional image URL.
3. Submit the form to persist the event through the event-service (`POST /api/events`). A success toast appears and the events table refreshes with the new entry.
4. Use the table's **Delete** button to remove events (`DELETE /api/events/:id`).

### Booking events as an attendee

1. Register or log in from the navbar.
2. Browse events on the home page. Filters, search, and sorting options are available in the event list.
3. Open an event to view details and reserve seats. Confirming a booking updates seat availability through the booking-service and event-service coordination.
4. Access **My Bookings** from the navbar to review reservations and cancel if supported.

### Tips for operators

- Event capacity and availability are enforced by the event-service middleware, so bookings will fail gracefully when seats run out.
- All admin-only endpoints validate JWTs and roles via the auth-service. Ensure you include the `Authorization: Bearer <token>` header when calling backend APIs directly.

## Notification Service

The notification service sends email notifications using **AWS SNS + Lambda + SES**:

- Welcome emails when users register
- Booking confirmation emails when users book events

### Architecture

```
Notification Service → SNS Topic → Lambda Function → SES → User Email
```

### How It Works

1. User registers/books event
2. Notification service publishes to SNS
3. Lambda function extracts user email
4. SES sends email to specific user

### Cloud Deployment

See [DEPLOYMENT_ORDER.md](DEPLOYMENT_ORDER.md) for complete deployment steps.

Quick summary:

```bash
cd infrastructure/scripts

# 1. Create EKS cluster
./setup-eks.sh

# 2. Deploy Lambda email sender (will ask for your email)
./deploy-lambda-email-sender.sh

# 3. Build and push images
./build-and-push-images.sh

# 4. Process templates
./process-templates.sh

# 5. Deploy services
./deploy-services.sh
```

For detailed architecture and troubleshooting, see [SNS_LAMBDA_SETUP.md](SNS_LAMBDA_SETUP.md).

## Environment Configuration

Each service directory and the frontend already include a committed `.env` file configured for local development. Key variables you can tweak are:

- `MONGO_URI` – MongoDB connection string
- `JWT_SECRET` – secret for signing auth tokens (auth service)
- `PORT` – optional override for default ports listed above
- `AUTH_SERVICE_URL` / `EVENT_SERVICE_URL` / `NOTIFICATION_SERVICE_URL` – internal service discovery URLs
- `SNS_TOPIC_ARN` – AWS SNS topic ARN for notifications (notification service)
- `AWS_REGION` – AWS region for SNS (notification service)

The frontend `.env` exposes `REACT_APP_AUTH_API_URL`, `REACT_APP_EVENT_API_URL`, and `REACT_APP_BOOKING_API_URL`. Adjust these if your backend runs on different hosts or ports.

## Testing

Each service currently includes placeholder npm test scripts. Extend these as needed and run them with `npm test` from the respective service directory.

## CI/CD Pipeline

EventSphere includes automated CI/CD workflows using GitHub Actions following industry-standard practices. The pipeline provides code quality checks, security scanning, Kubernetes validation, automated builds, and production deployment.

### Pipeline Flow

#### On Pull Requests (Continuous Integration)

The `ci.yml` workflow runs comprehensive validation checks:

```
Code Quality → Kubernetes Validation → Docker Build & Scan → Helm Validation → Kyverno Policy Check
```

- **Code Quality**: Runs tests and linting for all services
- **Kubernetes Validation**: Generates manifests and validates with kube-linter and kube-score
- **Docker Build & Scan**: Builds images and scans with Trivy for vulnerabilities
- **Helm Validation**: Validates Helm charts
- **Kyverno Policy Check**: Validates manifests against security policies
- All checks must pass before PR can be merged
- Fast feedback with parallel job execution where possible

#### On Main Branch (Continuous Deployment)

The `cd.yml` workflow handles deployment:

```
Build & Push Images → Deploy to EKS → Smoke Tests
```

- **Build & Push**: Builds Docker images, pushes to ECR, signs with Cosign
- **Deploy**: Verifies image signatures, deploys to EKS with Helm (atomic rollback enabled)
- **Smoke Tests**: Validates deployment health
- Automatic deployment to staging on push to main
- Production deployment via manual workflow dispatch

### Available Workflows

1. **CI Pipeline** (`ci.yml`) - **For Pull Requests and Feature Branches**
   - Runs on pull requests and pushes to `feature/**` and `fix/**` branches
   - **Code Quality Job**: Tests and linting for all services
   - **Kubernetes Validation Job**:
     - Generates Kubernetes manifests from templates
     - Validates with kube-linter (v0.6.5)
     - Scores with kube-score (v1.18.0)
   - **Docker Build & Scan Job**:
     - Builds all service images
     - Scans with Trivy for vulnerabilities
     - Uploads results to GitHub Security tab
   - **Helm Validation Job**: Validates Helm charts
   - **Kyverno Policy Check Job**:
     - Validates generated manifests against security policies
     - Uses Kyverno CLI (v1.12.0)
     - Blocks deployment if policies fail
   - **Purpose**: Comprehensive validation before code reaches main branch

2. **CD Pipeline** (`cd.yml`) - **For Main Branch Deployment**
   - Runs on push to `main` branch or manual workflow dispatch
   - **Build and Push Job**:
     - Builds Docker images for all services
     - Pushes to Amazon ECR
     - **Image Signing**: Images are signed with Cosign (keyless signing via OIDC)
     - Tags images with short commit SHA
   - **Deploy Job**:
     - **Image Verification**: Verifies image signatures before deployment (blocks if verification fails)
     - Installs Cosign and verifies all service images
     - Deploys to EKS using Helm with `--atomic` flag (automatic rollback on failure)
     - Verifies rollout status for all deployments
   - **Smoke Tests Job**:
     - Runs health checks on all deployed services
     - Validates pod status
   - **Environment Support**: Supports staging and production environments
   - **Safety**: Only deploys if cluster exists and is active

### Key Features

- **Image Signing & Verification**: All images are signed with Cosign and verified before deployment
- **Automatic Rollback**: Helm deployments use `--atomic` flag for automatic rollback on failure
- **Security Validation**: Kyverno policies enforce security best practices
- **Comprehensive Testing**: Multiple validation layers ensure code quality
- **Fast Feedback**: Parallel job execution where possible

### Pre-commit Hooks

EventSphere includes pre-commit hooks for code quality:

- **yamllint**: Validates YAML files
- **Prettier**: Formats JavaScript, JSON, YAML, Markdown, CSS
- **ShellCheck**: Lints shell scripts

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions.

### Quick Start - CI/CD

**On Pull Requests:**

```bash
# Create a PR - the ci.yml workflow runs automatically:
# 1. Code Quality → tests and linting
# 2. Kubernetes Validation → manifest validation
# 3. Docker Build & Scan → image security scanning
# 4. Helm Validation → chart validation
# 5. Kyverno Policy Check → security policy validation
# All checks must pass before PR can be merged
```

**On Main Branch (Automatic Deployment):**

```bash
# Merge PR to main - the cd.yml workflow runs automatically:
# 1. Build & Push → builds images, pushes to ECR, signs with Cosign
# 2. Deploy → verifies signatures, deploys to EKS with atomic rollback
# 3. Smoke Tests → validates deployment health
```

**Manual Production Deployment:**

```bash
# For other environments or manual triggers:
# Actions tab → "CD" → Run workflow
# Select environment: staging or production
# Requires: AWS infrastructure (EKS cluster) to be provisioned first
```

## Cloud Deployment (AWS EKS)

EventSphere is designed for production deployment on AWS EKS with full observability, security, and CI/CD integration.

### Quick Start - EKS Deployment

1. **Prerequisites**: AWS CLI, eksctl, kubectl, helm
2. **Create Cluster**: See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions
   ```bash
   cd infrastructure/scripts
   ./setup-eks.sh
   ```
3. **Configure Environment**: Set up `infrastructure/config/config.env` (see [Configuration](#configuration) below)
4. **Deploy Services**: Follow the deployment guide in [DEPLOYMENT.md](DEPLOYMENT.md)

### Configuration

Before deploying, you must configure `infrastructure/config/config.env`:

```bash
cd infrastructure/config
cp config.env.example config.env
```

Edit `config.env` with your values:

```bash
# AWS Configuration
# Leave empty to auto-detect from AWS CLI (recommended)
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"

# AWS Region
export AWS_REGION="${AWS_REGION:-us-east-1}"

# ACM Certificate ARN for HTTPS/TLS
# Get this from: aws acm list-certificates --region us-east-1
export ACM_CERTIFICATE_ARN="${ACM_CERTIFICATE_ARN:-arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/...}"

# Cluster Configuration
export CLUSTER_NAME="${CLUSTER_NAME:-eventsphere-cluster}"
```

**Important Notes:**

- **AWS_ACCOUNT_ID**: If left empty, the `process-templates.sh` script will auto-detect it from your AWS CLI credentials
- **ECR_REGISTRY**: Automatically calculated as `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com` after AWS_ACCOUNT_ID is set
- **IAM Role ARNs**: Automatically calculated from AWS_ACCOUNT_ID if not explicitly set
- If you manually set `AWS_ACCOUNT_ID`, ensure it matches your actual AWS account ID

### Common Configuration Issues

**Issue: InvalidImageName error with `.dkr.ecr.us-east-1.amazonaws.com`**

If you see pod errors like:

```
Failed to apply default image tag ".dkr.ecr.us-east-1.amazonaws.com/auth-service:latest":
couldn't parse image name: invalid reference format
```

**Root Cause**: `ECR_REGISTRY` was set before `AWS_ACCOUNT_ID` was detected, resulting in an invalid registry URL missing the account ID.

**Solution**:

1. Verify your `config.env` file doesn't have an incorrectly set `ECR_REGISTRY`
2. Ensure `AWS_ACCOUNT_ID` is either set explicitly or AWS CLI is configured for auto-detection
3. Re-run `process-templates.sh` - the script now automatically fixes invalid `ECR_REGISTRY` values
4. Verify the output shows a valid `ECR_REGISTRY`:
   ```bash
   ./scripts/process-templates.sh
   # Should show: ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com
   ```
5. If the issue persists, manually set `AWS_ACCOUNT_ID` in `config.env`:
   ```bash
   export AWS_ACCOUNT_ID="123456789012"
   ```

**Verification Steps After Configuration**:

After running `process-templates.sh`, verify the generated manifests:

```bash
# Check that ECR_REGISTRY is valid in generated deployments
grep -r "image:" k8s/generated/base/*.yaml

# Should show images like:
# image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
# NOT: image: .dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
```

### Key Features

- **Infrastructure**: EKS cluster with 3+ nodes across 2+ availability zones
- **Load Balancing**: AWS ALB with HTTPS/TLS termination
- **Auto-scaling**: HPA for pods, Cluster Autoscaler for nodes
- **Observability**: Prometheus, Grafana, CloudWatch Logs, and AlertManager (see [Observability](#observability) below)
- **Security**: GuardDuty, Security Hub, Network Policies, Pod Security Standards
- **CI/CD**: GitHub Actions workflows for security scanning, automated builds (GHCR), and EKS deployments
- **Secrets Management**: External Secrets Operator with AWS Secrets Manager

### Observability

EventSphere includes a comprehensive observability stack for monitoring, logging, and alerting:

#### Components

| Component        | Purpose                              | Access                          |
| ---------------- | ------------------------------------ | ------------------------------- |
| **Prometheus**   | Metrics collection and storage       | `localhost:9090` (port-forward) |
| **Grafana**      | Metrics visualization and dashboards | `localhost:3000` (port-forward) |
| **Fluent Bit**   | Container logs to CloudWatch         | AWS CloudWatch Console          |
| **AlertManager** | Alert routing and notifications      | Built into Prometheus stack     |

#### Accessing Dashboards

**Grafana**:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

- URL: http://localhost:3000
- Username: `admin`
- Password: `EventSphere2024`
- Includes EventSphere-specific dashboards for service metrics

**Prometheus**:

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

- URL: http://localhost:9090
- Query metrics, view targets, and check alert status

**CloudWatch Logs**:

- Log Group: `/aws/eks/eventsphere-cluster/application`
- View in AWS Console or via CLI:
  ```bash
  aws logs tail /aws/eks/eventsphere-cluster/application --follow
  ```

#### Configured Alerts

| Alert                      | Condition                     | Severity |
| -------------------------- | ----------------------------- | -------- |
| PodCrashLooping            | Pod restarting frequently     | Critical |
| PodNotReady                | Pod stuck in Pending/Failed   | Warning  |
| HighMemoryUsage            | Memory > 90% of limit         | Warning  |
| HighCPUUsage               | CPU > 80% of limit            | Warning  |
| DeploymentReplicasMismatch | Replicas not matching desired | Warning  |
| HPAAtMaxReplicas           | HPA at maximum for 15min      | Warning  |

#### Deployment

Observability is deployed automatically with the main deployment:

```bash
cd infrastructure/scripts
./deploy-services.sh
```

To skip monitoring deployment:

```bash
./deploy-services.sh --skip-monitoring
```

For more details, see [monitoring/README.md](monitoring/README.md).

### Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: System architecture and design
- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Step-by-step deployment guide
- **[SECURITY.md](SECURITY.md)**: Security measures and compliance
- **[CONTRIBUTING.md](CONTRIBUTING.md)**: Contribution guidelines

### Operational Runbooks

Comprehensive runbooks for operational procedures:

- **[Backup and Restore](docs/runbooks/BACKUP_RESTORE.md)**: Velero and manual EBS backup/restore procedures
- **[Disaster Recovery](docs/runbooks/DISASTER_RECOVERY.md)**: Complete cluster recovery procedures
- **[Security Incident Response](docs/runbooks/SECURITY_INCIDENT_RESPONSE.md)**: Incident classification and response
- **[Deployment and Rollback](docs/runbooks/DEPLOYMENT_ROLLBACK.md)**: Deployment strategies and rollback procedures
- **[Troubleshooting](docs/runbooks/TROUBLESHOOTING.md)**: Common issues and diagnostic procedures
- **[Maintenance](docs/runbooks/MAINTENANCE.md)**: Regular maintenance tasks and schedules
- **[Monitoring README](monitoring/README.md)**: Observability stack setup and usage
- **[Alert Handling](monitoring/alertmanager/runbook.md)**: Prometheus alert response procedures

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
