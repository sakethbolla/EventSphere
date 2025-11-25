# Contributing to EventSphere

Thank you for your interest in contributing to EventSphere! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect different viewpoints and experiences

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Docker and Docker Compose
- Git
- AWS CLI (for deployment)
- kubectl and eksctl (for Kubernetes)

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/EventSphere.git
   cd EventSphere
   ```

2. **Install Dependencies**
   ```bash
   # Backend services
   cd services/auth-service && npm install && cd ../..
   cd services/event-service && npm install && cd ../..
   cd services/booking-service && npm install && cd ../..
   
   # Frontend
   cd frontend && npm install && cd ..
   ```

3. **Start Local Development**
   ```bash
   # Start MongoDB
   docker-compose -f docker-compose.dev.yml up -d
   
   # Start services (in separate terminals)
   cd services/auth-service && npm run dev
   cd services/event-service && npm run dev
   cd services/booking-service && npm run dev
   
   # Start frontend
   cd frontend && npm start
   ```

## Git Workflow

### Branch Strategy

We use a **trunk-based development** approach:

- **main**: Production-ready code
- **develop**: Integration branch for features
- **feature/***: Feature branches
- **bugfix/***: Bug fix branches
- **hotfix/***: Critical production fixes

### Branch Naming

- `feature/add-user-profile`
- `bugfix/fix-booking-validation`
- `hotfix/security-patch`
- `docs/update-deployment-guide`

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(auth): add JWT token refresh endpoint

fix(booking): validate ticket quantity before booking

docs(deployment): update EKS setup instructions
```

## Pull Request Process

### Before Submitting

1. **Update Documentation**: Update relevant documentation
2. **Add Tests**: Add tests for new features or bug fixes
3. **Run Linters**: Ensure code passes linting
4. **Test Locally**: Verify changes work in local environment
5. **Update CHANGELOG**: Document changes (if applicable)

### Creating a Pull Request

1. **Create Branch**: From `develop` or `main`
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make Changes**: Implement your changes

3. **Commit Changes**: Use conventional commit format
   ```bash
   git add .
   git commit -m "feat(service): add new feature"
   ```

4. **Push Branch**: Push to your fork
   ```bash
   git push origin feature/my-feature
   ```

5. **Create PR**: Open a pull request on GitHub
   - Use the PR template
   - Link related issues
   - Request reviews from CODEOWNERS

### PR Requirements

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Security scans pass
- [ ] Docker images build successfully
- [ ] Kubernetes manifests validated

### Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Code Review**: At least one approval required
3. **Security Review**: Security team reviews security-related changes
4. **Merge**: After approval and all checks pass

## Code Style

### JavaScript/Node.js

- Use ESLint configuration (if available)
- Follow Airbnb JavaScript Style Guide
- Use async/await for asynchronous code
- Use meaningful variable and function names

### Docker

- Use multi-stage builds
- Keep images small
- Use specific tags (not `latest` in production)
- Include health checks

### Kubernetes

- Use consistent naming conventions
- Include resource limits
- Add labels and annotations
- Document complex configurations

## Testing

### Unit Tests

```bash
cd services/auth-service
npm test
```

### Integration Tests

```bash
# Run with Docker Compose
docker-compose up -d
npm run test:integration
```

### Manual Testing

1. Test locally with Docker Compose
2. Test in dev environment
3. Test in staging before production

## Documentation

### Code Documentation

- Add JSDoc comments for functions
- Document complex algorithms
- Explain non-obvious code

### API Documentation

- Document all API endpoints
- Include request/response examples
- Document error codes

### Infrastructure Documentation

- Update architecture diagrams
- Document configuration changes
- Update deployment guides

## Security

### Security Best Practices

- Never commit secrets or credentials
- Use environment variables for configuration
- Follow security guidelines in SECURITY.md
- Report security issues privately

### Reporting Security Issues

Email: security@enpm818rgroup7.work.gd

**Do NOT** create public GitHub issues for security vulnerabilities.

## Project Structure

```
EventSphere/
├── frontend/              # React frontend
├── services/              # Microservices
│   ├── auth-service/
│   ├── event-service/
│   └── booking-service/
├── k8s/                   # Kubernetes manifests
│   ├── base/
│   ├── mongodb/
│   ├── ingress/
│   ├── security/
│   └── hpa/
├── infrastructure/        # Infrastructure as Code
│   ├── eksctl-cluster.yaml
│   └── scripts/
├── monitoring/           # Monitoring configs
│   ├── prometheus/
│   ├── grafana/
│   └── cloudwatch/
├── .github/               # GitHub workflows and templates
│   ├── workflows/
│   └── CODEOWNERS
└── docs/                  # Documentation
```

## Code Ownership

See `.github/CODEOWNERS` for code ownership:

- `/infrastructure/` → @team-devops
- `/services/*/` → @team-backend
- `/frontend/` → @team-frontend
- `/k8s/security/` → @team-security @team-devops

## Getting Help

- **Documentation**: Check README.md and other docs
- **Issues**: Search existing issues or create new one
- **Discussions**: Use GitHub Discussions for questions
- **Slack**: Join our team Slack (if available)

## Release Process

1. **Version Bump**: Update version in package.json files
2. **Changelog**: Update CHANGELOG.md
3. **Tag Release**: Create git tag
4. **Deploy**: CI/CD pipeline deploys to production
5. **Announce**: Notify team of release

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Thank You!

Your contributions make EventSphere better for everyone. Thank you for taking the time to contribute!




