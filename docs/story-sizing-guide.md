# Story Sizing Guide — Robo Stack
## Contextual Lego Block Size Guidance

**Resolves:** OPS-B6 (GitHub Issue #45)
**Last Updated:** 2026-03-15
**Applies to:** All Robo Stack sprints

---

## Target Size by Story Type

| Story Type | Target Duration | Deliverable Scope | Lines of Code | Example |
|------------|----------------|-------------------|---------------|---------|
| **Process Design** | 2–4 hours | 1 design doc + Mermaid diagram | 0 (docs only) | S1.1 (#9), S2.1 (#19), S3.1 (#29) |
| **Build** | 4–8 hours | Code + tests + docs + PR | 100–500 lines | S1.3 (#11), S2.3 (#21), S3.2 (#30) |
| **Eval Gate** | 2–4 hours | 1 decision doc with hands-on testing | 0 (docs only) | EV1.1 (#14), EV2.1 (#25), EV3.1 (#34) |
| **Touchpoint** | 1–2 hours | Agenda + demo prep + summary | 0 (docs only) | TP2.1 (#26), TP3.1 (#35) |
| **OPS / Maintenance** | 1–2 hours | Script or doc or config change | 50–150 lines | OPS-B3 (#43), OPS-B5 (#44) |
| **Hotfix** | 1–3 hours | Targeted fix + regression test | 10–100 lines | S3.0 (#28) |
| **Architecture Doc** | 6–10 hours | Comprehensive HTML deliverable | 500–1200 lines | S3.6 (#39) |
| **Security Analysis** | 6–10 hours | Threat model or audit HTML | 500–1000 lines | S3.7 (#40) |

## Sizing Heuristics

### When to Split a Story
- Estimated duration exceeds 8 hours — split into waves or sub-tasks
- Story touches more than 2 system layers (e.g., Terraform + K8s + CI/CD)
- Story has internal dependencies (part B can't start until part A is done)
- Multiple personas needed (e.g., DevOps + Overwatch joint story)

### When to Combine Stories
- Two stories together take less than 2 hours
- Stories share the same branch and PR
- Stories are sequential with no review gate between them

### The "One PR" Rule
A well-sized Build story should result in exactly one PR. If a story requires multiple PRs, it's too big. If two stories share a PR, consider combining them.

**Exception:** Sprint 3.1 PR #56 merged S3.2–S3.5 in one PR (4,966 lines) because the stories were tightly coupled and tested together. This is acceptable when the dependency chain makes separate PRs impractical, but should be the exception.

## Sprint History — Sizing Analysis

| Sprint | Stories | Avg Duration | Largest | Smallest | Deferred |
|--------|---------|-------------|---------|----------|----------|
| Sprint 1 | 8 | ~4h | S1.5 Security (~6h) | EV1.1 Eval (~2h) | 1 (TP1) |
| Sprint 2 | 8 | ~5h | S2.3 Claude API (~8h) | TP2.1 Touchpoint (~1h) | 0 |
| Sprint 3.1 | 13 | ~4h | S3.6 Architecture (~8h) | OPS-B2 Dates (~0.5h) | 0 |

## Anti-Patterns

### Too Big (> 8 hours)
- "Build the entire monitoring + deployment + hardening stack" — This was Sprint 3.1's PR #56. It worked but was risky. Prefer wave separation.
- "Full security audit" — Split into: threat model, pen test, remediation.

### Too Small (< 1 hour)
- "Set a milestone due date" — This is a task, not a story. Group with related OPS work.
- "Fix a typo in docs" — Commit directly, don't create an issue.

### Unclear Scope
- "Improve CI/CD" — What specifically? Which workflow? What's the acceptance criteria?
- "Harden security" — Against what threats? Which components? What's the measurable outcome?

### Missing Acceptance Criteria
Every story, regardless of size, must have acceptance criteria that define "done." A story without ACs is not ready for sprint planning.

## Decision Rule

When in doubt, ask: "Can an agent complete this in a single focused session (4–8 hours) and produce a reviewable PR?" If yes, the size is right. If not, split it.
