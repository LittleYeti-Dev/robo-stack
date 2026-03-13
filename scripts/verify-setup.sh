#!/bin/bash
################################################################################
# Robo Stack - Workstation Setup Verification Script
################################################################################
# Sprint: Q1 2026 Infrastructure Setup
# Story: AS-001 Automated Developer Environment Configuration
# Acceptance Criteria:
#   - Validate all required tools are installed and accessible
#   - Check Docker daemon is running
#   - Verify Git configuration
#   - Color-coded PASS/FAIL output
#   - Non-zero exit code if any check fails
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Check counters
PASSED=0
FAILED=0

################################################################################
# Output Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}    Robo Stack Workstation Verification                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_check() {
    local name="$1"
    local status="$2"
    local detail="${3:-}"

    if [[ "$status" == "PASS" ]]; then
        ((PASSED++))
        printf "${GREEN}✓${NC} %-30s ${GREEN}PASS${NC}" "$name"
    elif [[ "$status" == "FAIL" ]]; then
        ((FAILED++))
        printf "${RED}✗${NC} %-30s ${RED}FAIL${NC}" "$name"
    else
        printf "  %-30s ${YELLOW}WARN${NC}" "$name"
    fi

    if [[ -n "$detail" ]]; then
        echo -e "  ${detail}"
    else
        echo ""
    fi
}

print_section() {
    echo ""
    echo -e "${BLUE}━━ $1 ━━${NC}"
}

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}║${NC}  Checks Passed: ${GREEN}%d${NC}  |  Checks Failed: " "$PASSED"
    if [[ $FAILED -eq 0 ]]; then
        printf "${GREEN}%d${NC}" "$FAILED"
    else
        printf "${RED}%d${NC}" "$FAILED"
    fi
    echo -e "                          ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

################################################################################
# Tool Verification Functions
################################################################################

check_command() {
    local cmd="$1"
    local name="${2:-$cmd}"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$("$cmd" --version 2>&1 | head -1 || echo "installed")
        print_check "$name" "PASS" "$version"
        return 0
    else
        print_check "$name" "FAIL" "Command not found"
        return 1
    fi
}

check_docker_daemon() {
    if docker ps >/dev/null 2>&1; then
        print_check "Docker Daemon" "PASS" "Running"
        return 0
    else
        print_check "Docker Daemon" "FAIL" "Not running or not accessible"
        return 1
    fi
}

check_docker_group() {
    local user
    user=$(whoami)

    if groups "$user" | grep -q docker; then
        print_check "Docker Group" "PASS" "User in docker group"
        return 0
    else
        print_check "Docker Group" "WARN" "User not in docker group (may need logout/login)"
        return 0
    fi
}

check_kubectl_context() {
    if kubectl config current-context >/dev/null 2>&1; then
        local context
        context=$(kubectl config current-context)
        print_check "kubectl Context" "PASS" "Current: $context"
        return 0
    else
        print_check "kubectl Context" "WARN" "No context configured (expected for fresh install)"
        return 0
    fi
}

check_git_config() {
    local user_name
    local user_email

    user_name=$(git config --global user.name || echo "")
    user_email=$(git config --global user.email || echo "")

    if [[ -n "$user_name" ]] && [[ -n "$user_email" ]]; then
        print_check "Git Configuration" "PASS" "$user_name <$user_email>"
        return 0
    else
        print_check "Git Configuration" "FAIL" "Missing user.name or user.email"
        return 1
    fi
}

check_terraform_plugins() {
    if [[ -d ~/.terraform.d ]]; then
        local plugin_count
        plugin_count=$(find ~/.terraform.d -name "terraform-provider-*" 2>/dev/null | wc -l)
        print_check "Terraform Plugins" "PASS" "Plugins dir exists (${plugin_count} providers)"
        return 0
    else
        print_check "Terraform Plugins" "WARN" "No plugins directory yet (will be created on first use)"
        return 0
    fi
}

check_vscode_extensions() {
    if command -v code >/dev/null 2>&1; then
        local ext_count
        ext_count=$(code --list-extensions 2>/dev/null | wc -l || echo "0")
        print_check "VS Code Extensions" "PASS" "$ext_count extensions installed"
        return 0
    else
        return 1
    fi
}

check_nodejs_nvm() {
    local nvm_dir="${HOME}/.nvm"
    if [[ -d "$nvm_dir" ]]; then
        # shellcheck source=/dev/null
        source "$nvm_dir/nvm.sh" 2>/dev/null || true
        if command -v node >/dev/null 2>&1; then
            local version
            version=$(node --version)
            print_check "Node.js (nvm)" "PASS" "$version"
            return 0
        fi
    fi
    return 1
}

check_npm_global() {
    if command -v npm >/dev/null 2>&1; then
        local prefix
        prefix=$(npm config get prefix)
        print_check "npm Prefix" "PASS" "$prefix"
        return 0
    else
        return 1
    fi
}

check_python_virtualenv() {
    if python3 -m venv --help >/dev/null 2>&1; then
        print_check "Python venv" "PASS" "Module available"
        return 0
    else
        print_check "Python venv" "FAIL" "Module not available"
        return 1
    fi
}

check_disk_space() {
    local available
    available=$(df -h "$HOME" | awk 'NR==2 {print $4}')
    print_check "Disk Space ($HOME)" "PASS" "$available available"
    return 0
}

check_memory() {
    local available
    available=$(free -h | awk 'NR==2 {print $7}')
    print_check "Available Memory" "PASS" "$available available"
    return 0
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header

    # System checks
    print_section "System Resources"
    check_memory
    check_disk_space

    # Core tools
    print_section "Core Development Tools"
    check_command "git" "Git"
    check_command "curl" "curl"
    check_command "wget" "wget"
    check_command "jq" "jq"
    check_command "yq" "yq"
    check_command "make" "make (build-essential)"

    # Containerization
    print_section "Container & Orchestration"
    check_command "docker" "Docker"
    check_docker_daemon
    check_docker_group
    check_command "docker-compose" "Docker Compose"
    check_command "kubectl" "kubectl"
    check_kubectl_context
    check_command "helm" "Helm"

    # Infrastructure
    print_section "Infrastructure & IaC"
    check_command "terraform" "Terraform"
    check_terraform_plugins

    # Development Tools
    print_section "Development Environments"
    check_command "code" "VS Code"
    check_vscode_extensions
    check_command "gh" "GitHub CLI"

    # Language Runtimes
    print_section "Language Runtimes"
    check_nodejs_nvm
    check_command "npm" "npm"
    check_npm_global
    check_command "python3" "Python 3"
    check_command "pip3" "pip3"
    check_python_virtualenv

    # Configuration
    print_section "Configuration & Setup"
    check_git_config

    # Summary
    print_summary

    # Exit with appropriate code
    if [[ $FAILED -gt 0 ]]; then
        echo -e "${RED}Some checks failed. Please review the output above.${NC}"
        echo ""
        exit 1
    else
        echo -e "${GREEN}All required tools are properly installed and configured!${NC}"
        echo ""
        exit 0
    fi
}

# Execute main
main "$@"
