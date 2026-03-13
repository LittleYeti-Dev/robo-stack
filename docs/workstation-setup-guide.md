# Robo Stack Automated Workstation Setup Guide

**Version:** 1.0
**Last Updated:** March 2026
**Sprint:** Q1 2026 Infrastructure Setup
**Story:** AS-001 Automated Developer Environment Configuration

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Post-Install Verification](#post-install-verification)
- [Tool Versions Reference](#tool-versions-reference)
- [Troubleshooting](#troubleshooting)
- [Manual Setup Steps](#manual-setup-steps)

---

## Prerequisites

### System Requirements

- **OS:** Ubuntu 22.04 LTS or later
- **RAM:** Minimum 8GB (16GB recommended for comfortable development)
- **CPU:** Minimum 4-core processor
- **Disk Space:** 50GB free space (for all tools and their cache directories)
- **Internet:** Active internet connection for downloading packages and tools

### Pre-Installation Checklist

- [ ] Running Ubuntu 22.04 LTS or later
- [ ] User account with sudo privileges
- [ ] Internet connectivity verified
- [ ] At least 50GB free disk space
- [ ] 8GB+ RAM available

### Verify Ubuntu Version

```bash
lsb_release -a
```

Expected output should show Ubuntu 22.04 or later.

---

## Quick Start

### One-Command Setup

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/robo-stack/repo/main/scripts/workstation-setup.sh)"
```

Or if you have the repository cloned locally:

```bash
bash ./scripts/workstation-setup.sh
```

The script will:
1. Validate your Ubuntu version
2. Update system packages
3. Install all development tools
4. Configure Docker daemon and user permissions
5. Generate a summary of installed tools with versions
6. Output a complete setup log

**Expected Duration:** 15-30 minutes (depending on internet speed and system performance)

### Verify Installation

After the script completes:

```bash
bash ./scripts/verify-setup.sh
```

This will check all tools and report their status with pass/fail indicators.

---

## Detailed Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/robo-stack/repo.git
cd repo
```

### Step 2: Review the Setup Script

```bash
cat scripts/workstation-setup.sh
```

Review the script to understand what will be installed. The script is idempotent and safe to run multiple times.

### Step 3: Make Scripts Executable

```bash
chmod +x scripts/workstation-setup.sh
chmod +x scripts/verify-setup.sh
```

### Step 4: Run the Setup Script

```bash
./scripts/workstation-setup.sh
```

Monitor the output for any warnings or errors. The script logs all operations to:

```
~/.robo-stack/logs/workstation-setup-YYYYMMDD-HHMMSS.log
```

### Step 5: Docker Group Membership

After the script completes, you need to apply the docker group membership:

```bash
# Log out and log back in, or use:
newgrp docker

# Verify docker access
docker ps
```

Without this step, you'll need to use `sudo docker` for all docker commands.

### Step 6: Configure Git (If Not Already Done)

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Step 7: Configure Node.js Environment (If Using nvm)

The Node.js installation uses nvm. Ensure nvm is properly initialized in your shell:

```bash
# For bash
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
source ~/.bashrc

# For zsh
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
source ~/.zshrc
```

---

## Post-Install Verification

### Run the Verification Script

```bash
./scripts/verify-setup.sh
```

This will check:
- All required tools are installed
- Docker daemon is running
- Git configuration is complete
- All language runtimes are accessible
- System resources are adequate

Expected output shows all checks with PASS status.

### Manual Quick Tests

#### Docker

```bash
docker run hello-world
```

Should display a "Hello from Docker!" message.

#### kubectl

```bash
kubectl version --client
```

Should show a version number (cluster context not required initially).

#### Terraform

```bash
terraform version
```

Should display the installed version.

#### Node.js & npm

```bash
node --version
npm --version
```

Should display version 18+ for Node.js.

#### Python

```bash
python3 --version
pip3 --version
```

Should display version 3.10+ for Python.

#### Helm

```bash
helm version
```

Should display version 3.x.

#### GitHub CLI

```bash
gh --version
```

Should display the installed version.

#### VS Code

```bash
code --version
```

Should display the installed version. Opens VS Code GUI if running with display server.

---

## Tool Versions Reference

| Tool | Minimum Version | Notes |
|------|-----------------|-------|
| Git | 2.25.0+ | Version manager, included in Ubuntu 22.04+ |
| Docker CE | 20.10+ | Latest stable from Docker repo |
| kubectl | 1.32+ | Latest from official Kubernetes repo |
| Helm | 3.0+ | Package manager for Kubernetes |
| Terraform | 1.0+ | Latest from HashiCorp repo |
| VS Code | 1.50+ | Latest from Microsoft repo |
| GitHub CLI | 2.0+ | Latest from GitHub repo |
| Node.js | 18.0+ (LTS) | Installed via nvm |
| npm | 9.0+ | Comes with Node.js |
| Python | 3.10+ | Python 3 from Ubuntu repo |
| pip | 22.0+ | Comes with Python 3 |
| virtualenv | 20.0+ | Installed via pip |

---

## Troubleshooting

### Issue: Script requires root/sudo

**Error:** "This script must NOT be run as root"

**Solution:**
```bash
# Run as regular user, NOT with sudo
bash ./scripts/workstation-setup.sh
```

The script uses `sudo` internally for privileged operations only.

---

### Issue: Docker: permission denied while trying to connect to Docker daemon

**Error:** `Cannot connect to Docker daemon`

**Solution:**
```bash
# Apply docker group membership
newgrp docker

# Or log out and log back in
logout
# Log back in

# Verify
docker ps
```

---

### Issue: Ubuntu version not supported

**Error:** "Ubuntu 22.04 LTS or later required"

**Solution:**
```bash
# Upgrade Ubuntu to 22.04 LTS or later
sudo do-release-upgrade
```

---

### Issue: kubectl: command not found after installation

**Error:** kubectl not found in PATH

**Solution:**
```bash
# Verify installation
which kubectl

# Try updating PATH
export PATH=$PATH:/usr/local/bin

# Or re-login for PATH to update
exit
```

---

### Issue: Node.js/npm not found

**Error:** `node: command not found`

**Solution:**
```bash
# Reload nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Verify
node --version
```

If nvm doesn't load, check installation:
```bash
ls -la ~/.nvm
```

---

### Issue: Terraform: command not found

**Error:** `terraform: command not found`

**Solution:**
```bash
# Verify installation
which terraform

# Check HashiCorp repo was added
apt-cache policy terraform

# Try updating PATH
export PATH=$PATH:/usr/bin

# Or manually install
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y terraform
```

---

### Issue: VS Code won't launch

**Error:** `code: command not found` or GUI doesn't open

**Solution:**
```bash
# Verify installation
which code

# Try launching with full path
/usr/bin/code

# Check if X11 display is available
echo $DISPLAY

# If on headless server, use code server instead
```

---

### Issue: Python virtualenv not working

**Error:** `python3 -m venv: No module named venv`

**Solution:**
```bash
# Install python3-venv
sudo apt-get install -y python3-venv

# Verify
python3 -m venv --help
```

---

### Issue: Git configuration not set

**Error:** Git commits fail with "Unknown committer"

**Solution:**
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify
git config --global --list
```

---

### Issue: Network timeout during installation

**Error:** curl/wget timeouts while downloading packages

**Solution:**
```bash
# Increase timeout and retry
curl --connect-timeout 30 --max-time 300 [url]

# Or re-run the setup script (it's idempotent)
bash ./scripts/workstation-setup.sh
```

---

### Issue: Insufficient disk space

**Error:** "No space left on device"

**Solution:**
```bash
# Check available space
df -h

# Free up space
sudo apt-get clean          # Remove apt cache
sudo apt-get autoclean      # Remove old packages
sudo apt-get autoremove     # Remove unused packages

# Or expand disk if using VM
```

---

### Issue: APT lock error

**Error:** `E: Could not get lock /var/lib/apt/lists/lock`

**Solution:**
```bash
# Wait for apt to finish
sudo lsof /var/lib/apt/lists/lock  # Find the process
sudo ps aux | grep apt             # List apt processes

# Or wait for updates to complete
sudo systemctl status apt-daily.service
sudo systemctl wait apt-daily.service

# Then re-run setup
bash ./scripts/workstation-setup.sh
```

---

## Manual Setup Steps

If you prefer to install tools manually or encounter issues with the automated script, follow these steps:

### 1. Update System Packages

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 2. Install Core Tools

```bash
sudo apt-get install -y git curl wget jq yq build-essential ca-certificates gnupg lsb-release
```

### 3. Install Docker

```bash
# Add Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start service
sudo systemctl enable docker
sudo systemctl start docker

# Add user to group
sudo usermod -aG docker $USER
newgrp docker
```

### 4. Install kubectl

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt-get update
sudo apt-get install -y kubectl
```

### 5. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 6. Install Terraform

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update
sudo apt-get install -y terraform
```

### 7. Install VS Code

```bash
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

sudo apt-get update
sudo apt-get install -y code
```

### 8. Install GitHub CLI

```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/github-cli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/github-cli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt-get update
sudo apt-get install -y gh
```

### 9. Install Node.js (via nvm)

```bash
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS
nvm install --lts
```

### 10. Install Python

```bash
sudo apt-get install -y python3 python3-pip python3-venv python3-dev

# Install virtualenv
python3 -m pip install --upgrade virtualenv
```

### 11. Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## Getting Help

### View Setup Log

```bash
cat ~/.robo-stack/logs/workstation-setup-*.log
```

### Check Individual Tool Status

```bash
# Docker
docker ps

# kubectl
kubectl version --client

# Terraform
terraform version

# Node.js
node --version && npm --version

# Python
python3 --version && pip3 --version

# Helm
helm version

# GitHub CLI
gh --version

# VS Code
code --version
```

### Report Issues

When reporting issues, include:

1. Ubuntu version: `lsb_release -a`
2. Last setup log: `~/.robo-stack/logs/workstation-setup-*.log`
3. Output from verification script: `./scripts/verify-setup.sh`
4. Error messages from failing commands

---

## Additional Resources

- [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Registry](https://registry.terraform.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [VS Code User Guide](https://code.visualstudio.com/docs)
- [GitHub CLI Manual](https://cli.github.com/manual)
- [Node.js Documentation](https://nodejs.org/en/docs/)
- [Python Documentation](https://docs.python.org/3/)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Mar 2026 | Initial release with automated setup for Ubuntu 22.04+ |

---

**Last Updated:** March 13, 2026
**Maintained by:** Robo Stack Platform Team
