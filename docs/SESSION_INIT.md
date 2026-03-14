# BOOT SEQUENCE — Yeti Knowledge Systems

**Effective:** 2026-03-14
**Authority:** Yeti (standing order — non-negotiable)
**Applies to:** ALL agents — DevOps, Cyber Ops, Taskmaster, Foreman, Overwatch, Cowork, Claude Code, any AI assistant touching this project
**Trigger:** When Yeti says "boot", read this file FIRST. Nothing else happens until this file is read and acknowledged.

> **If you are an AI agent reading this: these are your standing orders. Follow them exactly.**

---

## Step 0 — Get a GitHub PAT

Before you do ANYTHING else:

1. **Check if you already have a GitHub Personal Access Token (PAT) for this session.**
2. **If you do NOT have a PAT, ask Yeti immediately:**

> "I need a GitHub PAT with `repo` scope to access the project repository. Can you provide one for this session?"

**Do not proceed past this step without a valid PAT.** You cannot read project files, push code, or do any meaningful work without repo access. The PAT is your key to everything.

---

## Step 1 — Clone or Pull the Repo

**Repository:** `https://github.com/LittleYeti-Dev/robo-stack`
**Owner:** LittleYeti-Dev (Justin K.)
**Default branch:** `main`

```bash
# First session — clone
git clone https://LittleYeti-Dev:{PAT}@github.com/LittleYeti-Dev/robo-stack.git

# Returning session — pull latest
cd robo-stack && git pull origin main
```

**This repo is the single source of truth.** If a file isn't in this repo, it doesn't exist.

---

## Step 2 — Read Project Context (in order)

After cloning, read these files to understand current project state:

1. `docs/SESSION_INIT.md` — **THIS FILE** (you're reading it now)
2. `docs/devops-prompts/` — check for any open code prompts awaiting execution
3. Sprint Tracker — current task status across all sprints
4. Operational Playbook — platform details, tool hierarchy, credentials, architecture
5. Decision Register — all project decisions with context
6. Blocker Register — open and resolved blockers

**Note:** Some of these files may still be in the local Scrum Master folder (Cowork workspace) during the migration period. If you can't find them in the repo, check there — then commit them to GitHub.

---

## Step 3 — Request Remaining Credentials

Ask Yeti for any credentials you need beyond the GitHub PAT:

> "I also need the WordPress Application Password (username: `h3ndriksj`) for REST API access. Any other credentials for this session?"

| Credential | When Needed | How to Ask |
|-----------|------------|-----------|
| GitHub PAT | Always (Step 0) | "I need a GitHub PAT with `repo` scope" |
| WordPress App Password | Any WordPress/snippet work | "I need the WordPress Application Password for `h3ndriksj`" |
| Claude API Key | AI scoring or reformatter work | "I need the Claude API key for token vault storage" |

**Credential rules:** In-memory only. NEVER write to disk, files, commits, or logs. Assume any PAT is short-lived.

---

## Step 4 — Deliver Status Brief

Tell Yeti what you see:

- Current sprint status (what's open, what's closed)
- Any open blockers
- What's next on the task list
- Any files that need attention

Keep it short — 3-5 bullet points max.

---

## Step 5 — Begin Tasking

Now you're ready to work. Follow these rules for the entire session:

---

## Standing Rules

### Rule 1 — GitHub Is the Source of Truth

All project artifacts — code, prompts, documentation, evaluations, task lists, retros, and operational files — **must be committed to this GitHub repository**. No exceptions.

- **Every file you create** gets pushed to GitHub before the session ends
- **Every file you modify** gets committed and pushed
- **Local-only files are not acceptable** — the Scrum Master folder (Cowork workspace) is a scratchpad, not a permanent home
- **If it's not in the repo, it doesn't exist**

### Rule 2 — Folder Conventions

| Content Type | Repo Path |
|-------------|-----------|
| DevOps code prompts | `docs/devops-prompts/` |
| Cyber Ops prompts | `docs/cyber-prompts/` |
| Scrum/Taskmaster docs | `docs/scrum/` |
| Evaluations & evals | `docs/` (prefixed with `ev*.md`) |
| Sprint retros | `docs/` (prefixed with `sprint-*-retrospective.*`) |
| Workflow & ops guides | `docs/` |
| Infrastructure code | `terraform/`, `k8s/`, `scripts/` |
| CI/CD workflows | `.github/workflows/` |
| Security docs | Root (`SECURITY.md`) or `docs/security-*` |

If a folder doesn't exist for your content type, create it. Follow the naming patterns.

### Rule 3 — Commit Conventions

```
type(scope): short description

Optional longer description.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

| Field | Values |
|-------|--------|
| Types | `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci` |
| Scopes | `s0`–`s4` (sprint), `ev1.1`–`ev3.1` (eval), `security`, `infra` |
| Git identity | `user.name="LittleYeti-Dev"`, `user.email="h3ndriks.j@gmail.com"` |

### Rule 4 — Migration from GitLab

The project previously used GitLab (`gitlab.com/h3ndriks.j/JK.com-ver02`). As of 2026-03-13, **GitHub is the primary repo**. GitLab references in older docs are historical. Update them as you touch files — don't bulk-rewrite.

### Rule 5 — End of Session Checklist

Before closing ANY session:

- [ ] All new/modified files committed to GitHub
- [ ] Push to `origin/main` (or open PR for feature branches)
- [ ] Verify push: `git log origin/main --oneline -3`
- [ ] Report final commit hash to Yeti
- [ ] No credentials left in any files, logs, or commit messages

---

## Quick Reference

| Property | Value |
|----------|-------|
| GitHub Repo | `https://github.com/LittleYeti-Dev/robo-stack` |
| GitHub Username | `LittleYeti-Dev` |
| Commit Email | `h3ndriks.j@gmail.com` |
| WordPress Site | `https://justin-kuiper.com` |
| WP API Username | `h3ndriksj` |
| WP REST Base | `https://justin-kuiper.com/wp-json/` |
| WP Snippets API | `code-snippets/v1/snippets` |

---

*Standing order from Yeti — 2026-03-14. This file supersedes any conflicting instructions in older documents. When Yeti says "boot", this is where you start.*
