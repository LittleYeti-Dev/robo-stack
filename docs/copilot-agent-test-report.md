# S1.6: Copilot Agent Mode — Hands-On Test Report

**Date:** 2026-03-13
**Sprint:** 1
**GitHub Issue:** #15
**Tester:** Yeti (via Cowork orchestration)
**Persona:** AI Integration Specialist

---

## Task Attempted

**Prompt given:** Extend `workstation-setup.sh` to add lazydocker tool, create a test report documenting the experience.

**Complexity level:** Low-Medium — adding a single tool install function to an existing script, following established patterns.

**Agent used:** GitHub Copilot Coding Agent (cloud-hosted, triggered via GitHub issue/PR)

---

## What Happened

1. Copilot Agent Mode accepted the prompt and created branch `copilot/extend-workstation-setup-script`
2. PR #17 was opened with title "[WIP] Extend workstation-setup.sh to add lazydocker tool"
3. The Copilot coding agent workflow ran for **2 minutes 41 seconds**
4. Copilot wrote an "Initial plan" in the PR description restating the task
5. The agent committed an **empty commit** (zero file changes) with message "Initial plan"
6. The agent session was then **cancelled** — no code was produced
7. PR #17 was merged to main with **0 additions, 0 deletions**

---

## Results

| Metric | Result |
|--------|--------|
| Code produced | None (0 additions, 0 deletions) |
| Time spent | 2m 41s before cancellation |
| Files modified | 0 |
| Human intervention needed | 100% — task not completed |
| Quality of output | N/A — no output |
| CI status | Passed (nothing to fail on) |

---

## Analysis

### Where Copilot Struggled

- **Failed to produce any code.** The agent created a branch, opened a PR, wrote a plan description, then stopped. This is the most basic failure mode — the tool didn't do the job.
- **Empty commit.** The "Initial plan" commit contained no file changes. This suggests the agent's planning phase completed but execution never started.
- **Session cancellation.** The Copilot coding agent workflow shows "cancelled" status after ~2.5 minutes. Whether this was a timeout, resource limit, or internal error is unclear from the logs.

### Where Copilot Showed Promise

- **PR creation was clean.** Branch naming, PR title, and description were well-formed.
- **CI integration worked.** The PR triggered CI Pipeline and Security Scan workflows correctly, both passed.
- **Planning output was reasonable.** The PR description restated the task accurately.

### Comparison to Claude Code

| Capability | Copilot Agent Mode | Claude Code (Cowork) |
|-----------|-------------------|---------------------|
| Task completion | Did not complete | Completed all assigned stories (S1.1, EV1.1, plus all build work) |
| Code generation | 0 lines produced | Thousands of lines across Terraform, shell scripts, workflows, docs |
| Reliability | Agent cancelled mid-task | Ran to completion on every task |
| CI/CD authoring | Not tested (no output) | Created 4 working workflow files, debugged and fixed 6 issues |
| Infrastructure | Not tested | Full AWS deployment via Terraform (26 resources) |
| Error recovery | None observed | Self-corrected multiple Terraform and CI issues iteratively |
| Time to value | 2m 41s with no output | Hours of sustained productive work |

---

## Updated Agent Routing Recommendations

Based on Sprint 1 experience, the original routing table needs revision:

| Task Type | Original Assignment | Revised Assignment | Rationale |
|-----------|-------------------|-------------------|-----------|
| Architecture + design | Claude Code | Claude Code | Confirmed — strong performance |
| Evaluation + comparison | Claude Code | Claude Code | Confirmed — thorough analysis |
| Script generation | Copilot Agent Mode | Claude Code / Cowork | Copilot failed to deliver; Claude completed all scripts |
| CI/CD pipeline authoring | Copilot Agent Mode | Claude Code / Cowork | Claude authored all 4 workflows and fixed 6 issues |
| Terraform IaC | Copilot Agent Mode | Claude Code / Cowork | Claude deployed 26 AWS resources successfully |
| Sprint orchestration | Claude Cowork | Claude Cowork | Confirmed — strong performance |
| Code completion in IDE | GitHub Copilot (inline) | GitHub Copilot (inline) | Not tested in agent mode; inline completion remains useful |
| Copilot Agent Mode | Build tasks | Light scaffolding only | Unreliable for substantive agentic work in current form |

**Key insight:** Copilot Agent Mode (cloud-hosted coding agent) is not yet reliable for multi-step build tasks. It excels at inline code completion within VS Code but the autonomous agent mode cancelled before producing output. Claude Code/Cowork handled all substantive agentic work in Sprint 1 — from architecture design through live AWS deployment.

---

## Score

**Copilot Agent Mode for agentic coding tasks: 1/5**

Would not use again for substantive build work in its current form. Will re-evaluate as GitHub iterates on the product. Inline Copilot (non-agent) remains valuable for code completion and is not affected by this assessment.

---

## Recommendations for Sprint 2

1. **Route all agentic coding tasks to Claude Code/Cowork.** Copilot Agent Mode is not ready for production sprint work.
2. **Keep Copilot for inline completion.** It's still the best tool for in-editor autocomplete and suggestion.
3. **Re-test Copilot Agent Mode in Sprint 3.** GitHub ships updates frequently — give it another shot with a simpler task.
4. **Update the agent routing table** in boot-context.md and Sprint 2 planning docs.

---

## Artifacts

- PR #17: https://github.com/LittleYeti-Dev/robo-stack/pull/17
- Copilot coding agent run: cancelled after 2m 41s
- Branch: `copilot/extend-workstation-setup-script`
- Commit: `3503dfe` (empty — "Initial plan")
