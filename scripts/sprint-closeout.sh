#!/usr/bin/env bash
# sprint-closeout.sh — Automated sprint close-out procedure for Robo Stack
# Resolves: OPS-B3 (GitHub Issue #43)
# Usage: ./scripts/sprint-closeout.sh <milestone-name> [--dry-run]

set -euo pipefail

# --- Configuration ---
REPO="LittleYeti-Dev/robo-stack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Help ---
show_help() {
    cat <<HELP
Usage: $(basename "$0") <milestone-name> [--dry-run]

Sprint close-out procedure for Robo Stack.

Arguments:
  milestone-name    Name of the GitHub milestone to close (e.g., "Sprint 3.1")
  --dry-run         Show what would happen without making changes

Environment:
  GITHUB_TOKEN      Required. GitHub Personal Access Token with repo scope.

Checks performed:
  1. Verify all milestone issues are closed (or explicitly deferred)
  2. Report: total issues, closed, open, deferred
  3. Verify .taskmaster/status/ files are up to date
  4. Check for uncommitted local changes
  5. Check local/remote HEAD match
  6. Verify retrospective issue exists and is closed
  7. Generate close-out summary

Examples:
  GITHUB_TOKEN=ghp_xxx ./scripts/sprint-closeout.sh "Sprint 3.1"
  GITHUB_TOKEN=ghp_xxx ./scripts/sprint-closeout.sh "Sprint 3.1" --dry-run
HELP
    exit 0
}

# --- Args ---
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && show_help
[[ $# -lt 1 ]] && echo -e "${RED}Error: milestone name required. Use --help for usage.${NC}" && exit 1

MILESTONE_NAME="$1"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

# --- Validate ---
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable not set.${NC}"
    echo "Export your GitHub PAT: export GITHUB_TOKEN=ghp_..."
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() { echo -e "  ${GREEN}✅ PASS${NC} — $1"; ((PASS_COUNT++)); }
check_fail() { echo -e "  ${RED}❌ FAIL${NC} — $1"; ((FAIL_COUNT++)); }
check_warn() { echo -e "  ${YELLOW}⚠  WARN${NC} — $1"; ((WARN_COUNT++)); }

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Sprint Close-Out: ${MILESTONE_NAME}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}  [DRY RUN MODE — no changes will be made]${NC}"
echo ""

# --- Step 1: Fetch milestone data ---
echo -e "${BLUE}[1/6] Checking milestone issues...${NC}"

MILESTONE_JSON=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/milestones" | \
    python3 -c "
import sys, json
milestones = json.load(sys.stdin)
for m in milestones:
    if m['title'] == '$MILESTONE_NAME':
        print(json.dumps(m))
        sys.exit(0)
print('NOT_FOUND')
")

if [[ "$MILESTONE_JSON" == "NOT_FOUND" ]]; then
    check_fail "Milestone '$MILESTONE_NAME' not found"
    exit 1
fi

MILESTONE_NUM=$(echo "$MILESTONE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['number'])")
OPEN_COUNT=$(echo "$MILESTONE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['open_issues'])")
CLOSED_COUNT=$(echo "$MILESTONE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['closed_issues'])")
TOTAL=$((OPEN_COUNT + CLOSED_COUNT))

echo "  Total: $TOTAL | Closed: $CLOSED_COUNT | Open: $OPEN_COUNT"

if [[ "$OPEN_COUNT" -eq 0 ]]; then
    check_pass "All $TOTAL issues closed"
else
    # List open issues
    OPEN_ISSUES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO/issues?milestone=$MILESTONE_NUM&state=open&per_page=50")
    echo ""
    echo "  Open issues:"
    echo "$OPEN_ISSUES" | python3 -c "
import sys, json
issues = json.load(sys.stdin)
for i in issues:
    if 'pull_request' not in i:
        labels = ', '.join([l['name'] for l in i['labels']])
        print(f'    #{i[\"number\"]} | {i[\"title\"]} | {labels}')
"
    check_fail "$OPEN_COUNT issues still open"
fi

# --- Step 2: Check for retrospective ---
echo ""
echo -e "${BLUE}[2/6] Checking retrospective gate...${NC}"

RETRO_FOUND=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/issues?milestone=$MILESTONE_NUM&state=all&per_page=50" | \
    python3 -c "
import sys, json
issues = json.load(sys.stdin)
for i in issues:
    if 'RETRO' in i['title'].upper() or 'RETROSPECTIVE' in i['title'].upper():
        print(f'{i[\"number\"]}|{i[\"state\"]}|{i[\"title\"]}')
        break
else:
    print('NOT_FOUND')
")

if [[ "$RETRO_FOUND" == "NOT_FOUND" ]]; then
    check_fail "No retrospective issue found in milestone"
elif echo "$RETRO_FOUND" | grep -q "|closed|"; then
    check_pass "Retrospective issue closed: #$(echo "$RETRO_FOUND" | cut -d'|' -f1)"
else
    check_warn "Retrospective issue exists but not closed: #$(echo "$RETRO_FOUND" | cut -d'|' -f1)"
fi

# --- Step 3: Check .taskmaster/status/ ---
echo ""
echo -e "${BLUE}[3/6] Checking .taskmaster/status/ files...${NC}"

if [[ -f "$REPO_ROOT/.taskmaster/status/robo-stack.md" ]]; then
    LAST_UPDATED=$(grep -i "last updated" "$REPO_ROOT/.taskmaster/status/robo-stack.md" | head -1 || echo "unknown")
    check_pass "robo-stack.md exists ($LAST_UPDATED)"
else
    check_warn ".taskmaster/status/robo-stack.md not found"
fi

# --- Step 4: Check for uncommitted changes ---
echo ""
echo -e "${BLUE}[4/6] Checking for uncommitted changes...${NC}"

cd "$REPO_ROOT" 2>/dev/null || { check_warn "Cannot cd to repo root"; }

if git rev-parse --git-dir > /dev/null 2>&1; then
    STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l)
    UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l)
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

    if [[ $STAGED -eq 0 && $UNSTAGED -eq 0 && $UNTRACKED -eq 0 ]]; then
        check_pass "Working directory clean"
    else
        check_warn "Uncommitted changes: $STAGED staged, $UNSTAGED unstaged, $UNTRACKED untracked"
    fi
else
    check_warn "Not in a git repository"
fi

# --- Step 5: Check local/remote sync ---
echo ""
echo -e "${BLUE}[5/6] Checking git sync state...${NC}"

if git rev-parse --git-dir > /dev/null 2>&1; then
    git fetch origin --quiet 2>/dev/null || true
    LOCAL_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null || echo "unknown")

    if [[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]]; then
        check_pass "Local HEAD matches origin/main (${LOCAL_HEAD:0:7})"
    else
        check_fail "Local (${LOCAL_HEAD:0:7}) != Remote (${REMOTE_HEAD:0:7})"
    fi
else
    check_warn "Cannot verify git sync (not in repo)"
fi

# --- Step 6: Summary ---
echo ""
echo -e "${BLUE}[6/6] Close-out summary...${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  Milestone:  $MILESTONE_NAME"
echo -e "  Issues:     $CLOSED_COUNT/$TOTAL closed"
echo -e "  Checks:     ${GREEN}$PASS_COUNT pass${NC} / ${RED}$FAIL_COUNT fail${NC} / ${YELLOW}$WARN_COUNT warn${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}RESULT: READY TO CLOSE${NC}"
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo "  To close the milestone on GitHub:"
        echo "    curl -s -X PATCH -H 'Authorization: token \$GITHUB_TOKEN' \\"
        echo "      -d '{\"state\":\"closed\"}' \\"
        echo "      https://api.github.com/repos/$REPO/milestones/$MILESTONE_NUM"
    fi
else
    echo -e "  ${RED}RESULT: NOT READY — resolve $FAIL_COUNT failure(s) first${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

exit $FAIL_COUNT
