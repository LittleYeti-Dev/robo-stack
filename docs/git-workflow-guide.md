# Robo Stack Git Workflow Guide

This guide outlines the standard Git workflow, branching strategy, and CI/CD pipeline processes for the Robo Stack project.

## Table of Contents
- [Branch Naming Convention](#branch-naming-convention)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [CI/CD Pipeline Overview](#cicd-pipeline-overview)
- [Merge Strategy](#merge-strategy)
- [Handling Failed Checks](#handling-failed-checks)
- [Code Ownership](#code-ownership)

---

## Branch Naming Convention

All feature branches must follow this naming pattern:

```
feature/{project}-{epic}-{description}
```

### Examples
- `feature/robo-stack-deployment-k8s-manifests`
- `feature/robo-stack-security-add-trivy-scanning`
- `feature/robo-stack-ci-pipeline-shellcheck-validation`

### Branch Types
- **feature/**: For new features and enhancements
- **bugfix/**: For bug fixes
- **hotfix/**: For critical production fixes
- **docs/**: For documentation updates
- **chore/**: For maintenance and non-functional changes

### Naming Rules
- Use lowercase letters and numbers
- Separate words with hyphens (kebab-case)
- Keep descriptions concise and descriptive
- Do not use spaces, underscores, or special characters
- Maximum length: 50 characters

---

## Commit Message Format

Follow the Conventional Commits specification for clear, semantic commit messages.

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type
Must be one of:
- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect code meaning (formatting, missing semicolons, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to build process, CI/CD, dependencies, etc.
- **ci**: Changes to CI/CD configuration and scripts

### Scope
The scope specifies what part of the project is affected:
- `scripts`
- `k8s`
- `ci`
- `docs`
- etc.

### Subject
- Use the imperative mood ("add" not "added" or "adds")
- Do not capitalize the first letter
- Do not end with a period
- Maximum 50 characters

### Body
- Explain *what* and *why*, not *how*
- Wrap at 72 characters
- Separate from the subject with a blank line

### Footer
- Reference related issues: `Closes #123`
- Breaking changes: `BREAKING CHANGE: description`

### Examples

```
feat(ci): add trivy security scanning to ci pipeline

Add automated vulnerability scanning using trivy in the security job.
Scan results are uploaded to GitHub Security tab for visibility.

Closes #42
```

```
fix(scripts): correct kubectl configuration path

The verify-setup.sh script was using an incorrect kubeconfig path,
causing deployment verification to fail. Updated to use standard
$HOME/.kube/config location.

Closes #38
```

```
docs(readme): update installation instructions

Add detailed steps for local Kubernetes setup and explain how to
configure kubeconfig before running deployment scripts.
```

---

## Pull Request Process

### Creating a PR
1. **Push your branch** to the remote repository
   ```bash
   git push origin feature/robo-stack-{epic}-{description}
   ```

2. **Open a pull request** on GitHub
   - Target: `main` branch
   - Use the PR template (auto-populated)
   - Provide clear description of changes

3. **Complete the PR checklist**
   - All tests pass
   - Documentation updated
   - Security reviewed
   - ShellCheck passes
   - YAML linting passes
   - Commits follow conventional format

### PR Requirements
- All status checks must pass before merging
- At least one code owner review required
- No merge conflicts with base branch
- All conversations resolved

### Code Review Process
1. Request review from appropriate code owners (auto-requested by CODEOWNERS)
2. Address feedback promptly
3. Resolve all conversations before merge
4. Approve changes and merge

### Automated Checks
The CI pipeline automatically validates:
- **Linting**: ShellCheck (shell scripts), yamllint (YAML files)
- **Testing**: Verification script execution
- **Security**: Trivy vulnerability scanning

All checks must pass before merge is allowed.

---

## CI/CD Pipeline Overview

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Events                             │
│              (Push to main, PR to main)                     │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        v            v            v
   ┌────────┐  ┌────────┐  ┌──────────────┐
   │  Lint  │  │  Test  │  │   Security   │
   │        │  │        │  │     Scan     │
   └────────┘  └────────┘  └──────────────┘
        │            │            │
        └────────────┼────────────┘
                     │
              ┌──────v──────┐
              │   Approval  │
              │  Required   │
              └──────┬──────┘
                     │
              ┌──────v──────────────┐
              │  Merge to Main      │
              │ (Squash Merge)      │
              └──────┬──────────────┘
                     │
              ┌──────v──────────────┐
              │  Deploy to Local K8s│
              │   (Automatic)       │
              └─────────────────────┘
```

### CI Pipeline (ci.yml)

Triggered on:
- Push to `main` branch
- Pull requests to `main` branch

**Jobs:**

1. **Lint Job**
   - Installs ShellCheck and yamllint
   - Validates all `.sh` files for shell script quality
   - Validates all `.yml` and `.yaml` files for syntax and style
   - Fails if any linting errors detected

2. **Test Job**
   - Executes `scripts/verify-setup.sh`
   - Validates environment and configuration
   - Ensures deployment readiness

3. **Security Job**
   - Runs Trivy filesystem scan
   - Generates SARIF output for GitHub Security tab
   - Detects vulnerabilities in dependencies and containers
   - Results available in GitHub Security dashboard

### Deploy Pipeline (deploy-local.yml)

Triggered on:
- Push to `main` branch (after successful CI)
- Manual trigger via `workflow_dispatch`

**Job: Deploy K8s Manifests**
- Checks out code
- Installs kubectl
- Applies all manifests from `k8s/` directory
- Waits for deployments to reach ready state
- Posts deployment status to commit status API

**Status Checks:**
- `deployment/local-k8s` status appears on commits
- Success/failure clearly indicated

---

## Merge Strategy

### Squash Merge
All pull requests are merged to `main` using squash merge strategy.

**Benefits:**
- Clean, linear commit history
- Each PR results in exactly one commit
- Easier to revert changes if needed
- Cleaner bisect history for debugging

### Process
1. Ensure all CI checks pass
2. Obtain required code owner approval
3. Click "Squash and merge" button on GitHub
4. GitHub automatically cleans up feature branch

---

## Handling Failed Checks

### Linting Failures

**ShellCheck Errors:**
```bash
# Run locally to identify issues
shellcheck scripts/your-script.sh

# Common issues:
# SC2086: Quote variables to prevent word splitting
# SC2181: Check exit code directly
# SC2119: Use functions with parameters instead of globals
```

**yamllint Errors:**
```bash
# Run locally to identify issues
yamllint k8s/deployment.yaml

# Common issues:
# Indentation errors
# Line too long
# Incorrect spacing around colons
```

### Test Failures

**Verification Script Failure:**
```bash
# Run locally to debug
bash scripts/verify-setup.sh

# Check for:
# Missing environment variables
# Incorrect file permissions
# Invalid configuration files
# Missing dependencies
```

### Security Scan Failures

**Trivy Vulnerabilities:**
1. View results in GitHub Security tab
2. Review each vulnerability's severity
3. Either:
   - Update vulnerable dependencies
   - Add exception if vulnerability is not applicable
   - Document risk acceptance if appropriate

### Recovery Steps

1. **Identify the failure** from GitHub Actions logs
2. **Run tests locally** in your development environment
3. **Fix the issues** in your code
4. **Commit and push** the fixes
5. **Monitor the re-run** in GitHub Actions
6. **Request review** once all checks pass

### Retrying Checks

To manually re-run a failed job:
1. Go to Actions tab in GitHub
2. Select the workflow run
3. Click "Re-run failed jobs"
4. Monitor the output

---

## Code Ownership

Ownership is defined in `.github/CODEOWNERS` file. Code owners are automatically requested for review on relevant pull requests.

### Current Ownership
- **@LittleYeti-Dev**: scripts/, k8s/, .github/, docs/

### Requirements
- Changes to owned code require code owner approval
- Code owners should review PRs promptly
- Use GitHub's review features to approve or request changes

### Adding/Changing Owners
1. Update `.github/CODEOWNERS` file
2. Create PR for the change
3. Obtain approval from outgoing owner
4. Merge following standard process

---

## FAQ

### Can I merge without all checks passing?
No. Branch protection rules enforce that all status checks must pass before merge.

### How do I revert a merged change?
1. Create new branch from `main`
2. Create commit that reverts the change(s)
3. Use `git revert <commit-hash>` to create revert commit
4. Open PR with the revert
5. Follow normal merge process

### What if I need to hotfix production?
1. Create `hotfix/robo-stack-{description}` branch
2. Make minimal targeted fix
3. Open PR to `main`
4. Complete all reviews and checks
5. Merge using squash merge strategy
6. Deploy follows automatically

### How do I run CI checks locally?
```bash
# Linting
shellcheck scripts/*.sh
yamllint k8s/*.yaml

# Testing
bash scripts/verify-setup.sh

# Security scanning
trivy fs .
```

---

## References
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
