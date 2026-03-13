# Security Policy

## Reporting Security Vulnerabilities

If you discover a security vulnerability in the Robo Stack project, please report it responsibly and do **NOT** disclose it publicly until we have had a chance to address it.

### How to Report

1. **Email Security Team**: Send details to [security@your-org.com](mailto:security@your-org.com)
   - Include a clear description of the vulnerability
   - Steps to reproduce (if applicable)
   - Potential impact assessment
   - Your name and contact information

2. **GitHub Security Advisory** (Preferred for GitHub-hosted projects):
   - Go to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the vulnerability report form
   - This creates a private security advisory visible only to maintainers

3. **Third-Party Disclosure Platforms**:
   - HackerOne: [your-org.hackerone.com](https://your-org.hackerone.com)
   - Bugcrowd: [bugcrowd.com/your-org](https://bugcrowd.com/your-org)

### Response Timeline

- **Acknowledgment**: We will acknowledge your report within 24 hours
- **Investigation**: We will investigate and determine severity within 72 hours
- **Fix & Release**: Critical issues will be patched within 7 days; high-severity within 14 days
- **Public Disclosure**: Coordination with reporter on disclosure timeline (typically 90 days after fix)

## Supported Versions

| Version | Status | Support Until | Security Updates |
|---------|--------|---------------|------------------|
| 1.x     | Active | 2026-12-31    | Yes              |
| 0.x     | Legacy | 2025-06-30    | Critical only    |

Only the latest major version receives full security support. Previous versions receive critical security patches for 12 months after release.

## Security Practices

### Dependency Management

- **Automated Scanning**: Dependabot scans for vulnerable dependencies weekly
- **Prompt Updates**: We aim to patch critical vulnerabilities within 7 days
- **Audit**: Run `npm audit` or `pip audit` before deployment
- **Pinned Versions**: All CI/CD workflows use pinned dependency versions for reproducibility

### Code Analysis

- **Static Analysis**: CodeQL analysis runs on every PR and weekly schedule
- **Coverage**: JavaScript and Python code is scanned for security issues
- **Secrets Detection**: gitleaks prevents secrets from being committed
- **Container Scanning**: Trivy scans Docker images for vulnerabilities

### Secret Management

- **Never in Code**: Secrets must never be hardcoded or committed
- **Environment Variables**: Use `.env` files (gitignored) for local development
- **GitHub Secrets**: Use GitHub Actions secrets for CI/CD
- **Vault Integration**: Production deployments use secure secret vaults

### Access Control

- **Principle of Least Privilege**: Minimal necessary permissions for all roles
- **Branch Protection**: Main branch requires PR review and status checks
- **CODEOWNERS**: Critical files require review from designated owners
- **Audit Logging**: All deployments and access are logged

### Container Security

- **Base Images**: Use official, minimal base images (distroless, alpine)
- **Scanning**: All images scanned with Trivy before deployment
- **Non-Root**: Containers run as non-root user by default
- **Read-Only FS**: Root filesystem mounted as read-only where possible

### Development Practices

- **Code Review**: All changes require peer review before merge
- **Signed Commits**: GPG-signed commits encouraged for production branches
- **Testing**: Automated tests must pass before PR approval
- **Documentation**: Security-relevant code changes must be documented

## Incident Response

In the event of a security incident:

1. **Assessment**: Determine scope, severity, and affected versions
2. **Remediation**: Develop and test fix immediately
3. **Release**: Issue patch release with security fix
4. **Communication**: Notify users of vulnerability and update
5. **Post-Mortem**: Document lessons learned

## Security Compliance

This project aims to comply with:

- **OWASP Top 10**: Regular assessment against OWASP vulnerabilities
- **CWE/SANS Top 25**: Code analysis covers common weaknesses
- **NIST Cybersecurity Framework**: Follows NIST guidelines where applicable
- **GitHub Security Best Practices**: Implements GitHub-recommended security controls

## Third-Party Dependencies

We use several third-party tools for security:

- **GitHub Actions**: CodeQL, Dependabot, branch protection
- **Trivy**: Container image vulnerability scanning
- **gitleaks**: Secret detection in repositories
- **syft**: Software Bill of Materials (SBOM) generation

## Contact & Questions

For security questions or policy clarifications:

- **Security Issues**: [security@your-org.com](mailto:security@your-org.com)
- **General Questions**: [team@your-org.com](mailto:team@your-org.com)
- **GitHub Discussions**: [GitHub Discussions](../../discussions)

---

**Last Updated**: 2026-03-13
**Policy Version**: 1.0
