# Session Initiation Prompt — Yeti Knowledge Systems

**Effective:** 2026-03-14
**Authority:** Yeti (standing order)
**Applies to:** All agents — DevOps, Cyber Ops, Taskmaster, Foreman, Overwatch

---

## Rule 1 — GitHub Is the Source of Truth

**Repository:** `https://github.com/LittleYeti-Dev/robo-stack`
**Owner:** LittleYeti-Dev (Justin K.)
**Branch:** `main`

All project artifacts — code, prompts, documentation, evaluations, task lists, and operational files — **must be committed to this GitHub repository**. No exceptions.

### What this means:

- **Every file you create** (code prompts, retro docs, task lists, snippets, configs, evals) gets pushed to GitHub before the session ends
- **Every file you modify** gets committed and pushed
- **Local-only files are not acceptable** — if it's not in the repo, it doesn't exist
- **The Scrum Master folder** (local Cowork workspace) is a working scratchpad only, not a permanent home

### Folder conventions:

| Content Type | Repo Path |
|-------------|-----------|
| DevOps code prompts | `docs/devops-prompts/` |
| Evaluations & evals | `docs/` (prefixed with `ev*.md`) |
| Sprint retros | `docs/` (prefixed with `sprint-*-retrospective.*`) |
| Workflow guides | `docs/` |
| Infrastructure code | `terraform/`, `k8s/`, `scripts/` |
| CI/CD workflows | `.github/workflows/` |
| Security docs | Root (`SECURITY.md`) or `docs/security-*` |

If a folder doesn't exist yet for your content type, create it and follow the naming patterns above.

### Commit conventions:

Follow the existing commit message style in this repo:

```
type(scope): short description

Optional longer description.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`
Scopes: `s0`–`s4` (sprint), `ev1.1`–`ev3.1` (eval), `security`, `infra`

### Authentication:

- Request a GitHub PAT from Yeti at the start of every session
- Username for commits: `LittleYeti-Dev`
- Email for commits: `h3ndriks.j@gmail.com`
- Clone via HTTPS with PAT: `https://LittleYeti-Dev:{PAT}@github.com/LittleYeti-Dev/robo-stack.git`

---

## Rule 2 — Migration from GitLab

The project previously used GitLab (`gitlab.com/h3ndriks.j/JK.com-ver02`). As of 2026-03-13, **GitHub is the primary repo**. GitLab references in older docs (Operational Playbook, Sprint Tracker, Decision Register) are historical and should not be used for new work.

When updating legacy docs, replace GitLab references with GitHub equivalents where appropriate. Do not bulk-rewrite — update as you touch files.

---

## Rule 3 — Session Start Checklist

1. **Read this file** (`docs/SESSION_INIT.md`)
2. **Clone the repo** (or pull latest if already cloned)
3. **Request credentials** from Yeti: GitHub PAT + WordPress Application Password
4. **Read the Operational Playbook** (`Scrum Master/Operational_Playbook.md` or future GitHub location)
5. **Read the Sprint Tracker** for current status
6. **Deliver status brief** to Yeti
7. **Begin tasking** — all output goes to GitHub

---

## Rule 4 — End of Session

Before closing any session:

- [ ] All new/modified files committed to GitHub
- [ ] Push to `origin/main` (or open PR if working on a feature branch)
- [ ] Verify push succeeded (`git log origin/main --oneline -3`)
- [ ] Report commit hash to Yeti

---

*Standing order from Yeti — 2026-03-14. This file supersedes any conflicting instructions in older documents.*
