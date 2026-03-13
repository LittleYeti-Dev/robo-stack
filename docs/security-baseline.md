# Security Baseline Configuration

This document describes the security architecture and baseline controls implemented for the Robo Stack project.

## Table of Contents

1. [Overview](#overview)
2. [Dependency Management](#dependency-management)
3. [Static Analysis & Code Security](#static-analysis--code-security)
4. [Secret Management](#secret-management)
5. [Container Security](#container-security)
6. [Access Control Model](#access-control-model)
7. [Incident Response](#incident-response)
8. [Compliance & Auditing](#compliance--auditing)

## Overview

The Robo Stack security baseline establishes controls across the software development lifecycle:

```
┌─────────────────────────────────────────────────────────┐
│                  ROBO STACK SECURITY                    │
├─────────────────────────────────────────────────────────┤
│ Development  │ Code Analysis │ Scanning │ Deployment    │
│              │               │          │                │
│ • Git hooks  │ • CodeQL      │ • Trivy  │ • K8s RBAC    │
│ • .env vars  │ • gitleaks    │ • SBOM   │ • Secrets mgmt│
│ • Secrets    │ • Dependabot  │ • sysft  │ • Audit logs  │
│   management │               │          │                │
└─────────────────────────────────────────────────────────┘
```

All security controls are automated through GitHub Actions and integrated into the CI/CD pipeline.

## Dependency Management

### Dependabot Automation

**File**: `.github/dependabot.yml`

Dependabot automatically scans and updates dependencies on a weekly schedule (Monday mornings):

| Ecosystem | Frequency | Auto-PR | Group Strategy | PR Limit |
|-----------|-----------|---------|----------------|----------|
| npm       | Weekly    | Yes     | By type        | 10       |
| pip       | Weekly    | Yes     | By type        | 10       |
| docker    | Weekly    | Yes     | By type        | 3        |
| Actions   | Weekly    | Yes     | By type        | 5        |

### Update Strategy

- **Minor/Patch**: Automatically grouped into single PR for easier review
- **Major**: Separate PRs requiring explicit review and testing
- **Security**: Prioritized and flagged for immediate attention
- **Development**: Dev dependencies grouped separately

### Manual Auditing

Developers should regularly audit dependencies:

```bash
# npm
npm audit
npm audit fix  # Auto-fix if safe

# pip
pip audit
safety check
```

### Vulnerability Response

1. **Critical/High**: Patch within 7 days
2. **Medium**: Patch within 14 days
3. **Low**: Patch within 30 days or with next release

## Static Analysis & Code Security

### CodeQL Analysis

**File**: `.github/workflows/codeql.yml`

CodeQL performs deep semantic analysis on every PR and weekly scheduled basis:

#### Supported Languages
- **JavaScript**: Node.js, React, Express, etc.
- **Python**: Django, Flask, asyncio patterns

#### Analysis Scope

CodeQL identifies:
- **SQL Injection**: Database query vulnerabilities
- **Command Injection**: OS command execution risks
- **XSS Vulnerabilities**: Client-side injection
- **Path Traversal**: File access vulnerabilities
- **Insecure Deserialization**: Object deserialization attacks
- **Hardcoded Secrets**: API keys, passwords
- **Authentication Issues**: Authorization bypass
- **Cryptography Issues**: Weak crypto usage

#### Results

- Findings appear in GitHub Security tab
- Critical/High severity blocks PR merge
- Medium/Low severity flagged for review
- Weekly report sent to security team

### Secret Detection

**File**: `.github/workflows/security-scan.yml`

gitleaks scans commits and PR changes for exposed secrets:

#### Detected Secret Types

- AWS credentials, API keys
- GitHub tokens, SSH keys
- Private encryption keys (.pem, .key)
- OAuth tokens, API secrets
- Database passwords
- JWT tokens
- Generic password patterns

#### Policy

- **Prevention**: Pre-commit hooks catch secrets before commit
- **Detection**: gitleaks blocks PRs with secret findings
- **Remediation**: Secrets must be revoked and rotated immediately
- **Review**: Security team audits failed checks

### Preventing Secret Commits

#### Pre-Commit Hook Setup

```bash
# Install pre-commit framework
pip install pre-commit

# Install gitleaks
pre-commit install
```

#### Local Testing

```bash
# Test for secrets before committing
gitleaks detect --source . --verbose
```

## Container Security

### Trivy Vulnerability Scanning

**File**: `.github/workflows/security-scan.yml`

Trivy scans Docker images for known vulnerabilities:

#### Scan Targets

- **Base Images**: Official images scanned for vulnerabilities
- **Dependencies**: Dependencies in images checked against CVE databases
- **Configuration**: Container config analyzed for security issues
- **Artifacts**: Built images scanned before deployment

#### Severity Levels

| Level    | Action | Threshold |
|----------|--------|-----------|
| CRITICAL | Block  | 0 allowed |
| HIGH     | Block  | 0 allowed |
| MEDIUM   | Review | Flag only |
| LOW      | Log    | Flag only |

#### Image Building Best Practices

```dockerfile
# Use minimal base image
FROM node:20-alpine

# Run as non-root
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs

# Minimize layers
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy only necessary files
COPY --chown=nodejs:nodejs app/ /app/

# Use read-only root filesystem
RUN chown -R nodejs:nodejs /app
```

### Software Bill of Materials (SBOM)

**Tool**: syft

SBOM generated automatically on every push:

#### Formats Generated

- **CycloneDX JSON**: Standard format for components and dependencies
- **SPDX JSON**: Software package data exchange format

#### Usage

```bash
# Generate locally
syft . -o cyclonedx-json > sbom.json
syft . -o spdx-json > sbom-spdx.json

# View inventory
cat sbom.json | jq '.components[] | {name, version}'
```

#### Benefits

- Component visibility
- License compliance tracking
- Vulnerability correlation
- Supply chain security

## Secret Management

### Environment Variables

**No credentials in code or version control.**

#### Development

```bash
# 1. Copy template
cp .env.template .env

# 2. Fill in values for your local environment
nano .env

# 3. Load in shell (automatic with many frameworks)
source .env  # or: export $(cat .env | xargs)

# 4. .env is gitignored - never commit
cat .gitignore | grep ".env"
```

#### GitHub Secrets (CI/CD)

For workflows that need credentials:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.API_KEY }}
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
        run: ./deploy.sh
```

#### Kubernetes Secrets

For production deployments:

```bash
# Create secret from file
kubectl create secret generic db-password \
  --from-file=password=/run/secrets/db_password

# Reference in deployment
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-password
          key: password
```

### Secret Rotation

- **API Keys**: Rotate quarterly or on compromise
- **Database Passwords**: Rotate semi-annually
- **SSH/TLS Keys**: Rotate annually or per policy
- **Tokens**: Rotate immediately on suspected compromise

### Audit Trail

All secret access is logged (in production):

```bash
# Audit secret access in Kubernetes
kubectl logs -n kube-system kube-apiserver | grep "secret"

# Review GitHub secret access
# Settings → Security → Secret scanning → Review alerts
```

## Access Control Model

### Principle of Least Privilege

Users and services have only the minimum permissions required:

#### GitHub Repository

| Role | Permissions | Use Case |
|------|-------------|----------|
| Maintain | Code review, merge, releases | Team leads |
| Write | Code push, PR creation | Developers |
| Triage | Issues, PRs, discussions | QA, DevOps |
| Read | Code view, CI status | External team |

#### Kubernetes (RBAC)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]  # Read-only
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-role
subjects:
- kind: User
  name: developer@company.com
```

### Branch Protection

Main branch requires:

```
✓ PR review from code owner
✓ All status checks pass (CodeQL, tests, security scans)
✓ Up-to-date with base branch
✓ Signed commits (preferred)
✗ Force push blocked
```

Configuration:
- **Settings** → **Branches** → **Branch protection rules**

### Service Accounts

Service accounts for CI/CD use scoped credentials:

```yaml
# Example: GitHub Actions
- uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
    aws-region: us-east-1
```

## Incident Response

### Detection

Security incidents detected via:

1. **Automated Scanning**: CodeQL, gitleaks, Trivy alerts
2. **Monitoring**: Application logging, infrastructure monitoring
3. **User Reports**: Security report form or email
4. **Audit Logs**: GitHub, Kubernetes, cloud provider logs

### Response Process

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐
│  Incident   │───→│ Investigation│───→│  Mitigation │───→│ Post-Mortem │
│  Detection  │    │ & Assessment │    │  & Patching │    │ & Prevention│
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘
   (Alert)         (72 hours)           (7 days for       (14 days)
                                         critical)
```

### Runbook

1. **Acknowledge**: Confirm alert and assign team member
2. **Assess**: Determine severity, scope, and affected components
3. **Contain**: Stop the bleeding (isolate, revoke, patch)
4. **Eradicate**: Remove vulnerability or malicious code
5. **Recover**: Restore systems to known-good state
6. **Document**: Create post-mortem and action items

### Communication

- **Internal**: Slack #security, team meeting within 24 hours
- **External**: Affected users notified within 48-72 hours
- **Public**: Security advisory published 30 days after patch
- **Transparency**: Monthly security report to stakeholders

## Compliance & Auditing

### Automated Compliance

Policies enforced automatically:

- ✓ Dependencies up-to-date
- ✓ No hardcoded secrets
- ✓ Code analyzed for vulnerabilities
- ✓ Container images scanned
- ✓ All changes code-reviewed
- ✓ Signed commits on main (preferred)

### Manual Audits

Quarterly security reviews:

```bash
# 1. Review all commits in main branch
git log --oneline main | head -50

# 2. Check for recent secret detections
# Settings → Security → Secret scanning

# 3. Review Dependabot PRs and advisory alerts
# Security tab → Dependabot alerts

# 4. Check CodeQL findings
# Security tab → Code scanning

# 5. Review access logs
kubectl audit show --group=rbac
```

### Audit Logging

All security-relevant events are logged:

| Event Type | Source | Retention |
|-----------|--------|-----------|
| Code push | GitHub | Indefinite |
| PR merge | GitHub | Indefinite |
| Access | Kubernetes | 30 days |
| Secret access | Vault | 1 year |
| Deployment | CI/CD | 90 days |

### Reporting

Monthly security metrics:

```
Robo Stack Security Report - March 2026
───────────────────────────────────────
CodeQL Findings:         2 (1 fixed)
Dependabot Alerts:       3 (all updated)
Secret Detections:       0
Trivy Critical CVEs:     0
Failed Security Checks:  0
PRs Blocked:             0
───────────────────────────────────────
Overall Status:          PASSING ✓
```

---

## Resources

- [GitHub Security Docs](https://docs.github.com/en/code-security)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework/)

---

**Last Updated**: 2026-03-13
**Maintainer**: DevSecOps Team
**Status**: Active
