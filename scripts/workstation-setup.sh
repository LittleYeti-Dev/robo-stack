#!/bin/bash
################################################################################
# Robo Stack - Automated Ubuntu Developer Workstation Setup
################################################################################
# Sprint: Q1 2026 Infrastructure Setup
# Story: AS-001 Automated Developer Environment Configuration
# Acceptance Criteria:
#   - All tools installed and verified in one idempotent run
#   - Safe to execute multiple times without issues
#   - Proper error handling and detailed logging
#   - Summary output with all tool versions
#   - Works on Ubuntu 22.04 LTS and later
################################################################################

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/.robo-stack/logs"
readonly LOG_FILE="${LOG_DIR}/workstation-setup-$(date +%Y%m%d-%H%M%S).log"
readonly INSTALL_LOG="${LOG_DIR}/installs.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Ensure log directory exists
mkdir -p "$LOG_DIR"

################################################################################
# Logging Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

################################################################################
# Utility Functions
################################################################################

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script must NOT be run as root"
        exit 1
    fi
}

check_ubuntu_version() {
    local version_id
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        log_error "This script is designed for Ubuntu. Detected: ${NAME:-Unknown}"
        exit 1
    fi

    version_id="${VERSION_ID:-}"
    log_info "Detected Ubuntu ${version_id}"

    # Require Ubuntu 22.04 or later
    local major minor
    major=$(echo "$version_id" | cut -d. -f1)
    minor=$(echo "$version_id" | cut -d. -f2)

    if (( major < 22 )) || { (( major == 22 )) && (( minor < 4 )); }; then
        log_error "Ubuntu 22.04 LTS or later required. Current: ${version_id}"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_version() {
    local cmd="$1"
    local flag="${2:---version}"

    if command_exists "$cmd"; then
        # Try to get version, handle various output formats
        if $cmd $flag 2>&1 | head -1; then
            return 0
        fi
    fi
    return 1
}

record_install() {
    local tool="$1"
    local version="$2"
    echo "${tool}|${version}|$(date '+%Y-%m-%d %H:%M:%S')" >> "$INSTALL_LOG"
}

################################################################################
# System Updates
################################################################################

update_system_packages() {
    log_info "Updating system packages..."

    if sudo apt-get update -qq; then
        log_success "APT cache updated"
    else
        log_error "Failed to update APT cache"
        return 1
    fi

    if sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq; then
        log_success "System packages upgraded"
    else
        log_error "Failed to upgrade packages"
        return 1
    fi
}

################################################################################
# Install Core Tools
################################################################################

install_core_tools() {
    log_info "Installing core development tools..."

    local tools="git curl wget jq yq build-essential ca-certificates gnupg lsb-release"

    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $tools; then
        log_success "Core tools installed"

        # Verify installations
        for tool in git curl wget jq yq build-essential; do
            if command_exists "$tool"; then
                local version
                version=$(get_version "$tool" || echo "unknown")
                log_success "${tool}: ${version}"
                record_install "$tool" "$version"
            else
                log_error "${tool} installation verification failed"
                return 1
            fi
        done
    else
        log_error "Failed to install core tools"
        return 1
    fi
}

################################################################################
# Docker Installation
################################################################################

install_docker() {
    log_info "Installing Docker CE..."

    # Check if Docker is already installed
    if command_exists docker; then
        local version
        version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_warn "Docker already installed: ${version}"
        record_install "docker" "$version"

        # Ensure user is in docker group
        add_user_to_docker_group
        return 0
    fi

    # Add Docker GPG key
    local gpg_key_url="https://download.docker.com/linux/ubuntu/gpg"
    local gpg_key_file="/etc/apt/keyrings/docker.gpg"

    log_info "Adding Docker GPG key..."
    if ! sudo mkdir -p /etc/apt/keyrings; then
        log_error "Failed to create keyrings directory"
        return 1
    fi

    if ! curl -fsSL "$gpg_key_url" | sudo gpg --dearmor -o "$gpg_key_file" 2>/dev/null; then
        log_error "Failed to add Docker GPG key"
        return 1
    fi

    # Add Docker repository
    log_info "Adding Docker repository..."
    local repo_entry="deb [arch=$(dpkg --print-architecture) signed-by=${gpg_key_file}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    if ! echo "$repo_entry" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1; then
        log_error "Failed to add Docker repository"
        return 1
    fi

    if ! sudo apt-get update -qq; then
        log_error "Failed to update APT cache after adding Docker repo"
        return 1
    fi

    # Install Docker
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Failed to install Docker packages"
        return 1
    fi

    log_success "Docker CE installed"

    # Start Docker daemon
    if sudo systemctl enable docker && sudo systemctl start docker; then
        log_success "Docker daemon enabled and started"
    else
        log_error "Failed to start Docker daemon"
        return 1
    fi

    # Add user to docker group
    add_user_to_docker_group

    # Verify installation
    local version
    version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    log_success "Docker verified: ${version}"
    record_install "docker" "$version"
}

add_user_to_docker_group() {
    local current_user
    current_user=$(whoami)

    if ! groups "$current_user" | grep -q docker; then
        log_info "Adding user to docker group..."
        if sudo usermod -aG docker "$current_user"; then
            log_success "User added to docker group"
            log_warn "You may need to log out and log back in for group membership to take effect"
        else
            log_error "Failed to add user to docker group"
            return 1
        fi
    fi
}

################################################################################
# kubectl Installation
################################################################################

install_kubectl() {
    log_info "Installing kubectl..."

    if command_exists kubectl; then
        local version
        version=$(kubectl version --client --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
        log_warn "kubectl already installed: ${version}"
        record_install "kubectl" "$version"
        return 0
    fi

    # Add Kubernetes APT repository
    log_info "Adding Kubernetes APT repository..."

    if ! curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null; then
        log_error "Failed to add Kubernetes GPG key"
        return 1
    fi

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null 2>&1

    if ! sudo apt-get update -qq; then
        log_error "Failed to update APT cache after adding Kubernetes repo"
        return 1
    fi

    # Install kubectl
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubectl; then
        log_error "Failed to install kubectl"
        return 1
    fi

    log_success "kubectl installed"

    # Verify installation
    local version
    version=$(kubectl version --client --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    log_success "kubectl verified: ${version}"
    record_install "kubectl" "$version"
}

################################################################################
# Helm Installation
################################################################################

install_helm() {
    log_info "Installing Helm 3..."

    if command_exists helm; then
        local version
        version=$(helm version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
        log_warn "Helm already installed: ${version}"
        record_install "helm" "$version"
        return 0
    fi

    # Download Helm installation script
    local helm_script_url="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
    local helm_script="/tmp/get-helm-3.sh"

    log_info "Downloading Helm installation script..."
    if ! curl -fsSL "$helm_script_url" -o "$helm_script"; then
        log_error "Failed to download Helm installation script"
        return 1
    fi

    # Install Helm
    if ! bash "$helm_script"; then
        log_error "Failed to install Helm"
        rm -f "$helm_script"
        return 1
    fi

    rm -f "$helm_script"
    log_success "Helm installed"

    # Verify installation
    local version
    version=$(helm version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    log_success "Helm verified: ${version}"
    record_install "helm" "$version"
}

################################################################################
# Terraform Installation
################################################################################

install_terraform() {
    log_info "Installing Terraform..."

    if command_exists terraform; then
        local version
        version=$(terraform version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
        log_warn "Terraform already installed: ${version}"
        record_install "terraform" "$version"
        return 0
    fi

    # Add HashiCorp APT repository
    log_info "Adding HashiCorp APT repository..."

    if ! curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg 2>/dev/null; then
        log_error "Failed to add HashiCorp GPG key"
        return 1
    fi

    echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null 2>&1

    if ! sudo apt-get update -qq; then
        log_error "Failed to update APT cache after adding HashiCorp repo"
        return 1
    fi

    # Install Terraform
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq terraform; then
        log_error "Failed to install Terraform"
        return 1
    fi

    log_success "Terraform installed"

    # Verify installation
    local version
    version=$(terraform version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    log_success "Terraform verified: ${version}"
    record_install "terraform" "$version"
}

################################################################################
# VS Code Installation
################################################################################

install_vscode() {
    log_info "Installing Visual Studio Code..."

    if command_exists code; then
        local version
        version=$(code --version 2>/dev/null | head -1)
        log_warn "VS Code already installed: ${version}"
        record_install "code" "$version"
        return 0
    fi

    # Add Microsoft GPG key
    log_info "Adding Microsoft GPG key..."

    if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null 2>&1; then
        log_error "Failed to add Microsoft GPG key"
        return 1
    fi

    # Add VS Code repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null 2>&1

    if ! sudo apt-get update -qq; then
        log_error "Failed to update APT cache after adding VS Code repo"
        return 1
    fi

    # Install VS Code
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq code; then
        log_error "Failed to install VS Code"
        return 1
    fi

    log_success "VS Code installed"

    # Verify installation
    local version
    version=$(code --version 2>/dev/null | head -1)
    log_success "VS Code verified: ${version}"
    record_install "code" "$version"
}

################################################################################
# GitHub CLI Installation
################################################################################

install_github_cli() {
    log_info "Installing GitHub CLI..."

    if command_exists gh; then
        local version
        version=$(gh --version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
        log_warn "GitHub CLI already installed: ${version}"
        record_install "gh" "$version"
        return 0
    fi

    # Add GitHub CLI repository
    log_info "Adding GitHub CLI repository..."

    if ! curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/github-cli-archive-keyring.gpg 2>/dev/null; then
        log_error "Failed to add GitHub CLI GPG key"
        return 1
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/github-cli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null 2>&1

    if ! sudo apt-get update -qq; then
        log_error "Failed to update APT cache after adding GitHub CLI repo"
        return 1
    fi

    # Install GitHub CLI
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh; then
        log_error "Failed to install GitHub CLI"
        return 1
    fi

    log_success "GitHub CLI installed"

    # Verify installation
    local version
    version=$(gh --version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)
    log_success "GitHub CLI verified: ${version}"
    record_install "gh" "$version"
}

################################################################################
# Node.js LTS Installation (via nvm)
################################################################################

install_nodejs() {
    log_info "Installing Node.js LTS (via nvm)..."

    local nvm_dir="${HOME}/.nvm"

    # Check if nvm is already installed
    if [[ -d "$nvm_dir" ]]; then
        log_warn "nvm already installed at ${nvm_dir}"
        # shellcheck source=/dev/null
        source "$nvm_dir/nvm.sh"
        local version
        version=$(node --version 2>/dev/null)
        log_success "Node.js already installed: ${version}"
        record_install "node" "$version"
        return 0
    fi

    # Download nvm
    local nvm_url="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh"
    log_info "Downloading nvm..."

    if ! curl -fsSL "$nvm_url" | bash; then
        log_error "Failed to install nvm"
        return 1
    fi

    # Source nvm
    # shellcheck source=/dev/null
    source "$nvm_dir/nvm.sh"

    # Install Node.js LTS
    log_info "Installing Node.js LTS..."
    if ! nvm install --lts; then
        log_error "Failed to install Node.js LTS"
        return 1
    fi

    log_success "nvm and Node.js LTS installed"

    # Verify installation
    local version
    version=$(node --version 2>/dev/null)
    log_success "Node.js verified: ${version}"
    record_install "node" "$version"

    # Verify npm
    local npm_version
    npm_version=$(npm --version 2>/dev/null)
    log_success "npm verified: ${npm_version}"
    record_install "npm" "$npm_version"
}

################################################################################
# Python Installation
################################################################################

install_python() {
    log_info "Installing Python 3, pip, and virtualenv..."

    # Install Python packages
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-pip python3-venv python3-dev; then
        log_error "Failed to install Python packages"
        return 1
    fi

    log_success "Python packages installed"

    # Verify installations
    local py_version
    py_version=$(python3 --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
    log_success "Python3 verified: ${py_version}"
    record_install "python3" "$py_version"

    local pip_version
    pip_version=$(pip3 --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
    log_success "pip3 verified: ${pip_version}"
    record_install "pip3" "$pip_version"

    # Install virtualenv using pip
    log_info "Installing virtualenv via pip..."
    if python3 -m pip install --quiet --upgrade virtualenv; then
        local venv_version
        venv_version=$(virtualenv --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
        log_success "virtualenv verified: ${venv_version}"
        record_install "virtualenv" "$venv_version"
    else
        log_error "Failed to install virtualenv"
        return 1
    fi
}

################################################################################
# Git Configuration Check
################################################################################

check_git_config() {
    log_info "Checking Git configuration..."

    local user_name
    local user_email

    user_name=$(git config --global user.name || echo "")
    user_email=$(git config --global user.email || echo "")

    if [[ -z "$user_name" ]] || [[ -z "$user_email" ]]; then
        log_warn "Git user configuration not set. Please configure:"
        log_warn "  git config --global user.name 'Your Name'"
        log_warn "  git config --global user.email 'your.email@example.com'"
    else
        log_success "Git user configured: ${user_name} <${user_email}>"
    fi
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}    Robo Stack Workstation Setup - Installation Complete   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ -f "$INSTALL_LOG" ]]; then
        echo -e "${GREEN}Installation Summary:${NC}"
        echo ""
        printf "%-20s | %-30s | %s\n" "Tool" "Version" "Installed At"
        echo "─────────────────────┼────────────────────────────────┼────────────────────────"

        while IFS='|' read -r tool version timestamp; do
            printf "%-20s | %-30s | %s\n" "$tool" "$version" "$timestamp"
        done < "$INSTALL_LOG"
    fi

    echo ""
    echo -e "${GREEN}Quick Start Commands:${NC}"
    echo ""
    echo "  Verify setup:        ${BLUE}${SCRIPT_DIR}/verify-setup.sh${NC}"
    echo "  Docker test:         ${BLUE}docker run hello-world${NC}"
    echo "  kubectl config:      ${BLUE}kubectl config view${NC}"
    echo "  Terraform version:   ${BLUE}terraform version${NC}"
    echo "  Node.js REPL:        ${BLUE}node${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Docker group membership requires logout/login to take effect"
    echo ""
    echo -e "${GREEN}Setup log:${NC} ${LOG_FILE}"
    echo ""
}

################################################################################
# Error Handling
################################################################################

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Setup failed with exit code: $exit_code"
        log_error "See full log at: ${LOG_FILE}"
    fi
    exit "$exit_code"
}

trap cleanup EXIT

################################################################################
# Main Execution
################################################################################

main() {
    log_info "╔════════════════════════════════════════════════════════════╗"
    log_info "║     Robo Stack Automated Workstation Setup v1.0            ║"
    log_info "╚════════════════════════════════════════════════════════════╝"
    log_info ""
    log_info "Current user: $(whoami)"
    log_info "Log file: ${LOG_FILE}"
    log_info ""

    # Pre-checks
    check_root
    check_ubuntu_version

    # Clear install log at start of fresh run
    > "$INSTALL_LOG"

    # Run installation steps
    update_system_packages
    install_core_tools
    install_docker
    install_kubectl
    install_helm
    install_terraform
    install_vscode
    install_github_cli
    install_nodejs
    install_python
    check_git_config

    # Print summary
    print_summary

    log_success "Workstation setup completed successfully!"
}

# Execute main function
main "$@"
