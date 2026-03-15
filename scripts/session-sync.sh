#!/usr/bin/env bash
# session-sync.sh — Git sync verification and enforcement at session close
# Resolves: OPS-B5 (GitHub Issue #44)
# Usage: ./scripts/session-sync.sh [--auto-commit] [--help]

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Help ---
show_help() {
    cat <<HELP
Usage: $(basename "$0") [--auto-commit] [--help]

Verify git sync state at session close. Run this BEFORE ending any session
to prevent context drift between sessions.

Options:
  --auto-commit   Automatically stage, commit, and push uncommitted changes
                  with a session-close message
  --help, -h      Show this help

Checks performed:
  1. Uncommitted changes (staged, unstaged, untracked)
  2. Local HEAD vs remote HEAD match
  3. Unpushed commits
  4. Status file freshness (.taskmaster/status/)

Examples:
  ./scripts/session-sync.sh                  # Check only (read-only)
  ./scripts/session-sync.sh --auto-commit    # Check and push if needed
HELP
    exit 0
}

# --- Args ---
AUTO_COMMIT=false
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && show_help
[[ "${1:-}" == "--auto-commit" ]] && AUTO_COMMIT=true

# --- Verify we're in a git repo ---
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: not in a git repository.${NC}"
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
PASS_COUNT=0
FAIL_COUNT=0

check_pass() { echo -e "  ${GREEN}✅${NC} $1"; ((PASS_COUNT++)); }
check_fail() { echo -e "  ${RED}❌${NC} $1"; ((FAIL_COUNT++)); }

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Session Sync Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# --- Check 1: Uncommitted changes ---
echo -e "${BLUE}[1/4] Uncommitted changes...${NC}"

STAGED=$(git diff --cached --name-only | wc -l)
UNSTAGED=$(git diff --name-only | wc -l)
UNTRACKED=$(git ls-files --others --exclude-standard | wc -l)

if [[ $STAGED -eq 0 && $UNSTAGED -eq 0 && $UNTRACKED -eq 0 ]]; then
    check_pass "Working directory clean"
else
    if [[ $STAGED -gt 0 ]]; then
        check_fail "$STAGED staged but uncommitted file(s):"
        git diff --cached --name-only | sed 's/^/        /'
    fi
    if [[ $UNSTAGED -gt 0 ]]; then
        check_fail "$UNSTAGED unstaged modification(s):"
        git diff --name-only | sed 's/^/        /'
    fi
    if [[ $UNTRACKED -gt 0 ]]; then
        check_fail "$UNTRACKED untracked file(s):"
        git ls-files --others --exclude-standard | sed 's/^/        /'
    fi

    if [[ "$AUTO_COMMIT" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}Auto-committing...${NC}"
        git add -A
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        git commit -m "session-close: auto-sync at $TIMESTAMP

Automated commit by session-sync.sh --auto-commit.
Files: $((STAGED + UNSTAGED + UNTRACKED)) changed."
        echo -e "  ${GREEN}Committed.${NC}"
    fi
fi

# --- Check 2: Local vs remote HEAD ---
echo ""
echo -e "${BLUE}[2/4] Local/remote sync...${NC}"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch origin --quiet 2>/dev/null || echo -e "  ${YELLOW}Warning: could not fetch from origin${NC}"

LOCAL_HEAD=$(git rev-parse HEAD)
REMOTE_REF="origin/$CURRENT_BRANCH"
REMOTE_HEAD=$(git rev-parse "$REMOTE_REF" 2>/dev/null || echo "NOT_FOUND")

if [[ "$REMOTE_HEAD" == "NOT_FOUND" ]]; then
    check_fail "Remote branch $REMOTE_REF does not exist"
elif [[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]]; then
    check_pass "HEAD matches $REMOTE_REF (${LOCAL_HEAD:0:7})"
else
    check_fail "HEAD mismatch: local=${LOCAL_HEAD:0:7} remote=${REMOTE_HEAD:0:7}"
fi

# --- Check 3: Unpushed commits ---
echo ""
echo -e "${BLUE}[3/4] Unpushed commits...${NC}"

if [[ "$REMOTE_HEAD" != "NOT_FOUND" ]]; then
    UNPUSHED=$(git log "$REMOTE_REF..HEAD" --oneline 2>/dev/null | wc -l)
    if [[ $UNPUSHED -eq 0 ]]; then
        check_pass "No unpushed commits"
    else
        check_fail "$UNPUSHED unpushed commit(s):"
        git log "$REMOTE_REF..HEAD" --oneline | sed 's/^/        /'

        if [[ "$AUTO_COMMIT" == true ]]; then
            echo ""
            echo -e "  ${YELLOW}Pushing to $REMOTE_REF...${NC}"
            git push origin "$CURRENT_BRANCH"
            echo -e "  ${GREEN}Pushed.${NC}"
        fi
    fi
else
    check_fail "Cannot check unpushed commits (no remote tracking branch)"
fi

# --- Check 4: Status file freshness ---
echo ""
echo -e "${BLUE}[4/4] Status file freshness...${NC}"

STATUS_FILE="$REPO_ROOT/.taskmaster/status/robo-stack.md"
if [[ -f "$STATUS_FILE" ]]; then
    # Check if modified in last 24 hours
    FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$STATUS_FILE" 2>/dev/null || stat -f %m "$STATUS_FILE" 2>/dev/null || echo 0) ))
    if [[ $FILE_AGE -lt 86400 ]]; then
        check_pass "robo-stack.md updated within 24h"
    else
        DAYS_OLD=$((FILE_AGE / 86400))
        check_fail "robo-stack.md is ${DAYS_OLD} day(s) old — update before closing session"
    fi
else
    check_fail ".taskmaster/status/robo-stack.md not found"
fi

# --- Summary ---
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "  Branch:  $CURRENT_BRANCH"
echo -e "  Result:  ${GREEN}$PASS_COUNT pass${NC} / ${RED}$FAIL_COUNT fail${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}Session sync: CLEAN${NC}"
else
    echo -e "  ${RED}Session sync: DIRTY — fix before closing${NC}"
    [[ "$AUTO_COMMIT" == false ]] && echo -e "  Tip: run with ${YELLOW}--auto-commit${NC} to fix automatically"
fi
echo -e "${BLUE}═══════════════════════════════════════${NC}"

exit $FAIL_COUNT
