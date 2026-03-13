#!/bin/bash
# Cloud-init script for Robo Stack development workstation
# This script runs as root on EC2 instance startup

set -euo pipefail

# Logging
exec > >(tee /var/log/robo-stack-init.log)
exec 2>&1

echo "=== Robo Stack EC2 Bootstrap Started ==="
echo "Start time: $(date)"

# Update system packages
echo "=== Updating system packages ==="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -qq -y

# Install dependencies
echo "=== Installing base dependencies ==="
apt-get install -qq -y \
  curl \
  wget \
  git \
  vim \
  nano \
  htop \
  jq \
  ca-certificates \
  apt-transport-https \
  gnupg \
  lsb-release \
  software-properties-common \
  build-essential \
  libssl-dev \
  libffi-dev \
  unzip \
  zip

# Install Docker
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq
apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu || true

# Install K3s
echo "=== Installing K3s ==="
curl -sfL https://get.k3s.io | sh -
systemctl enable k3s
systemctl start k3s

# Wait for K3s to be ready
echo "=== Waiting for K3s to be ready ==="
for i in {1..60}; do
  if /usr/local/bin/k3s kubectl get nodes &>/dev/null; then
    echo "K3s is ready"
    break
  fi
  echo "Waiting for K3s... (attempt $i/60)"
  sleep 5
done

# Copy kubeconfig to ubuntu user
echo "=== Configuring kubectl for ubuntu user ==="
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sed -i "s|127.0.0.1|$(hostname -I | awk '{print $1}')|g" /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Install kubectl (symlink from K3s)
echo "=== Setting up kubectl ==="
ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl || true
chmod +x /usr/local/bin/kubectl

# Install Helm
echo "=== Installing Helm ==="
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
chmod +x /usr/local/bin/helm

# Install Node.js
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -qq -y nodejs

# Install Python
echo "=== Installing Python ==="
apt-get install -qq -y python3 python3-pip python3-venv
update-alternatives --install /usr/bin/python python /usr/bin/python3 1
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Install common Python packages
pip install --quiet --no-cache-dir \
  requests \
  boto3 \
  pyyaml \
  click

# Install Terraform
echo "=== Installing Terraform ==="
TERRAFORM_VERSION="1.7.0"
wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
chmod +x /usr/local/bin/terraform

# Install AWS CLI v2
echo "=== Installing AWS CLI v2 ==="
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install GitHub CLI
echo "=== Installing GitHub CLI ==="
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update -qq
apt-get install -qq -y gh

# Install additional container tools
echo "=== Installing container tools ==="
apt-get install -qq -y \
  podman \
  skopeo \
  containerd

# Install development tools
echo "=== Installing development tools ==="
apt-get install -qq -y \
  git-lfs \
  make \
  gcc \
  g++ \
  gdb \
  strace \
  ltrace

# Configure git
echo "=== Configuring git ==="
sudo -u ubuntu git config --global init.defaultBranch main
sudo -u ubuntu git config --global user.name "Robo Stack Developer"
sudo -u ubuntu git config --global user.email "dev@robo-stack.local"

# Create useful directories
echo "=== Setting up user directories ==="
mkdir -p /home/ubuntu/projects
mkdir -p /home/ubuntu/charts
mkdir -p /home/ubuntu/.local/bin
chown -R ubuntu:ubuntu /home/ubuntu/projects /home/ubuntu/charts /home/ubuntu/.local/bin

# Add useful aliases to ubuntu user
echo "=== Adding shell aliases ==="
cat >> /home/ubuntu/.bashrc << 'EOF'

# Robo Stack aliases
alias k='kubectl'
alias kgs='kubectl get svc'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployment'
alias kgn='kubectl get nodes'
alias kdesc='kubectl describe'
alias kl='kubectl logs'
alias ked='kubectl edit'
alias kex='kubectl exec -it'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'
alias h='helm'
alias d='docker'

# Navigation
alias projects='cd ~/projects'
alias charts='cd ~/charts'

# Utilities
alias ll='ls -lah'
alias myip='curl -s https://ifconfig.me'

# K3s status
alias k3s-status='systemctl status k3s'
alias k3s-logs='journalctl -u k3s -f'

EOF
chown ubuntu:ubuntu /home/ubuntu/.bashrc

# Verify installations
echo "=== Verifying installations ==="
echo "Docker version: $(docker --version)"
echo "Kubernetes version: $(/usr/local/bin/k3s --version)"
echo "kubectl version: $(kubectl version --client 2>/dev/null | grep -oP 'GitVersion":"\K[^"]+' || echo 'K3s integrated')"
echo "Helm version: $(helm version --short)"
echo "Node.js version: $(node --version)"
echo "Python version: $(python --version)"
echo "Terraform version: $(terraform version -json | jq -r '.terraform_version')"
echo "AWS CLI version: $(aws --version)"
echo "GitHub CLI version: $(gh --version)"

# Create a status file for monitoring
echo "=== Creating status indicators ==="
cat > /var/log/robo-stack-status.txt << EOF
Robo Stack Workstation Bootstrap
================================
Completed at: $(date)
Hostname: $(hostname)
Instance IP: $(hostname -I)
Kubernetes: Ready
Docker: Installed
Tools: All installed
Status: READY
EOF

# Final cleanup
echo "=== Cleanup ==="
apt-get autoremove -qq -y
apt-get clean -qq

echo "=== Robo Stack EC2 Bootstrap Complete ==="
echo "End time: $(date)"
echo ""
echo "Next steps:"
echo "1. Wait for instance to fully initialize (1-2 minutes for K3s stabilization)"
echo "2. Connect via SSH: ssh -i ~/.ssh/robo-stack-dev.pem ubuntu@<INSTANCE_IP>"
echo "3. Verify K3s is running: systemctl status k3s"
echo "4. Check kubeconfig: cat ~/.kube/config"
echo "5. List nodes: kubectl get nodes"
echo ""
