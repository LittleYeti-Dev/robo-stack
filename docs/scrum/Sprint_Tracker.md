# The Markdown — Sprint Tracker

**Last Updated:** 2026-03-13 (S3.8.8 closed — Snippet Integrity Protocol integrated into Playbook)
**Source of Truth:** [GitLab Issues](https://gitlab.com/h3ndriks.j/JK.com-ver02/-/issues)
**Total Tasks:** 124 | **Closed:** 108 | **Open:** 16
**Pipelines:** All passing ✅ | **CI Note:** `snippet-integrity` job defined but blocked (BLK-007 — missing CI variables)

---

## Sprint 0 — Immediate Hardening

**Status:** ✅ COMPLETE (Milestone CLOSED) | **Tasks:** 7/7 closed | **Milestone:** Sprint 0 — Immediate Hardening
**Gate:** G0 PASSED

| # | ID | Type | Task | Owner | Labels | Status | Closed |
|---|-----|------|------|-------|--------|--------|--------|
| 1 | S0.1 | SEC | Harden wp-config.php — move above webroot, set file permissions 400 | Cyber Ops | Critical | ✅ CLOSED | 2026-03-08 |
| 2 | S0.2 | SEC | Disable XML-RPC — block xmlrpc.php at server level | Cyber Ops | High | ✅ CLOSED | 2026-03-08 |
| 3 | S0.3 | SEC | Remove default admin account — create unique admin username | Taskmaster | High | ✅ CLOSED | 2026-03-08 |
| 4 | S0.4 | SEC | Set security headers — CSP, X-Frame-Options, HSTS, X-Content-Type | Cyber Ops | Critical | ✅ CLOSED | 2026-03-08 |
| 5 | S0.5 | SEC | Enforce HTTPS everywhere — redirect all HTTP to HTTPS | Cyber Ops | Critical | ✅ CLOSED | 2026-03-08 |
| 6 | S0.6 | SEC | Disable directory listing — prevent index browsing | Cyber Ops | High | ✅ CLOSED | 2026-03-08 |
| 7 | S0.7 | SEC | Hide WordPress version — remove generator meta tag | Cyber Ops | High | ✅ CLOSED | 2026-03-08 |

---

## Sprint 1 — Foundation Build

**Status:** ✅ COMPLETE (Milestone CLOSED) | **Tasks:** 23/23 closed | **Milestone:** Sprint 1 — Foundation Build
**Gates:** G1 ✅ PASSED | G2 ✅ PASSED | G3 ✅ PASSED

### Gate 1 — Data Model (S1.1–S1.3) ✅ COMPLETE

| # | ID | Type | Task | Owner | Status | Closed |
|---|-----|------|------|-------|--------|--------|
| 8 | S1.1 | FUNC | Register `ns_feed_item` CPT with 15 meta fields | DevOps | ✅ CLOSED | 2026-03-08 |
| 9 | S1.2 | FUNC | Register 4 custom taxonomies | DevOps | ✅ CLOSED | 2026-03-08 |
| 10 | S1.3 | SEC | Input validation on all CPT meta fields — sanitize, validate, escape | Cyber Ops | ✅ CLOSED | 2026-03-08 |

### Gate 2 — RSS/AI Pipeline (S1.4–S1.11) ✅ COMPLETE

| # | ID | Type | Task | Owner | Status | Closed |
|---|-----|------|------|-------|--------|--------|
| 11 | S1.4 | FUNC | Configure WP RSS Aggregator Pro — purchase, install, map to CPT | DevOps | ✅ CLOSED | 2026-03-08 |
| 12 | S1.5 | FUNC | Configure 40 starter feeds across 6 domains | Taskmaster | ✅ CLOSED | 2026-03-08 |
| 13 | S1.6 | FUNC | Build auto-domain tagging — keyword rules assign content_domain | DevOps | ✅ CLOSED | 2026-03-08 |
| 14 | S1.7 | FUNC | Build dedup logic — URL matching + title similarity 90% | DevOps | ✅ CLOSED | 2026-03-08 |
| 15 | S1.8 | SEC | RSS feed sanitization — strip scripts, validate URLs, limit payload | Cyber Ops | ✅ CLOSED | 2026-03-08 |
| 16 | S1.9 | FUNC | Build Claude feed scoring — 4h cron, relevance 1-10 | DevOps | ✅ CLOSED | 2026-03-08 |
| 17 | S1.10 | FUNC | Build morning digest — daily 0600 CST, top 20 items | DevOps | ✅ CLOSED | 2026-03-08 |
| 18 | S1.11 | SEC | Prompt injection detection — input filtering on RSS-to-LLM pipeline | Cyber Ops | ✅ CLOSED | 2026-03-08 |

### Gate 3 — Foundation (S1.12–S1.22) ✅ COMPLETE

| # | ID | Type | Task | Owner | Labels | Status | Closed |
|---|-----|------|------|-------|--------|--------|--------|
| 19 | S1.12 | FUNC | Build editorial dashboard — admin feed list with filters | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 20 | S1.13 | FUNC | Build promote button + block assignment dropdown | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 21 | S1.14 | FUNC | Build custom page template — 7-block layout rendering | Foreman | deployed | ✅ CLOSED | 2026-03-09 |
| 22 | S1.15 | FUNC | Build commentary cards — 3 embed styles | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 23 | S1.16 | FUNC | Build auto-refresh — AJAX polling every 15 min | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 24 | S1.17 | SEC | Build token vault — encrypted wp_options, AES-256 | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 25 | S1.18 | SEC | Nonce verification on all admin AJAX endpoints | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 26 | S1.19 | SEC | Application passwords for REST API auth | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 27 | S1.20 | SEC | Claude API key rotation procedure — document + test | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 28 | S1.21 | SEC | Rate limiting on custom REST endpoints (60 req/min/IP) | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 29 | S1.22 | SEC | Audit logging — custom DB table for all admin actions | DevOps | deployed | ✅ CLOSED | 2026-03-09 |

---

## Sprint 1.5 — Integration Gate

**Status:** ✅ COMPLETE | **Tasks:** 8/8 closed | **Milestone:** Sprint 1.5 — Integration Gate (CLOSED)
**Estimated:** ~10h | **Gate Criteria:** S1.5.1 + S1.5.2 must pass with zero failures — ✅ GATE PASSED

### Verification (Must Pass)

| # | ID | Type | Task | Owner | Labels | Status |
|---|-----|------|------|-------|--------|--------|
| 74 | S1.5.1 | VERIFY | Full-chain smoke test — RSS → AI → dashboard → promote → render → commentary → refresh → digest | DevOps + Foreman | Critical | ✅ CLOSED 2026-03-09 (8 PASS, 2 PARTIAL) |
| 75 | S1.5.2 | VERIFY | Security stack verification — vault, nonce, rate limit, audit log, diagnostic logger | Cyber Ops | Critical | ✅ CLOSED 2026-03-09 (6/6 PASS) |

### Operational Readiness

| # | ID | Type | Task | Owner | Labels | Status |
|---|-----|------|------|-------|--------|--------|
| 76 | S1.5.3 | OPS | Snippet inventory audit — all active snippets, load order, dependencies | DevOps | — | ✅ CLOSED 2026-03-09 |
| 77 | S1.5.4 | OPS | Refactor Sprint 1 monolithic snippets that caused WAF issues | DevOps | High | ✅ CLOSED 2026-03-09 (assessed, deferred to S2) |
| 78 | S1.5.5 | OPS | Build Operational Playbook — platform, APIs, credentials, tool hierarchy | Taskmaster | Critical | ✅ CLOSED 2026-03-09 |
| 79 | S1.5.6 | OPS | Define credential handling protocol in Playbook | Taskmaster + Cyber Ops | Critical | ✅ CLOSED 2026-03-09 |
| 80 | S1.5.7 | OPS | Update all continuity artifacts for micro-snippet architecture | Taskmaster | High | ✅ CLOSED 2026-03-09 |

### Admin

| # | ID | Type | Task | Owner | Labels | Status |
|---|-----|------|------|-------|--------|--------|
| 81 | S1.5.8 | ADMIN | Close S0/S1 milestones, assign S1.23, set milestone due dates | Taskmaster | — | ✅ CLOSED 2026-03-09 |

---

## Sprint 2 — Social & Publishing

**Status:** 🔶 21/22 CLOSED (S2.3 deferred to S3.5) | **Tasks:** 21/22 closed | **Milestone:** Sprint 2 — Social & Publishing
**Estimated:** ~86h

### Gate 4 — Social APIs (S2.1–S2.8) — 7/8 CLOSED (S2.3 deferred)

| # | ID | Type | Task | Owner | Labels | Status | Closed |
|---|-----|------|------|-------|--------|--------|--------|
| 30 | S2.1 | FUNC | Build X (Twitter) API integration — OAuth 2.0 PKCE, tweet + thread | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 31 | S2.2 | FUNC | Build LinkedIn API integration — OAuth 2.0, personal profile posting | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 32 | S2.3 | FUNC | Build Instagram API integration — Graph API via Facebook | DevOps | Deferred | ➡️ MOVED TO S3.5 (BLK-001) | — |
| 33 | S2.4 | FUNC | Build YouTube API integration — Data API v3, community posts | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 34 | S2.5 | FUNC | Build Medium API integration — bearer token, draft creation | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 35 | S2.6 | SEC | OAuth callback URL validation — whitelist registered callbacks | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 36 | S2.7 | SEC | Token refresh automation — daily cron, email alert on failure | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 37 | S2.8 | SEC | Platform API error handling — graceful failure, no token leakage | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |

### Gate 5 — AI + Quick-Publish (S2.9–S2.22) — ✅ 14/14 CLOSED

| # | ID | Type | Task | Owner | Labels | Status | Closed |
|---|-----|------|------|-------|--------|--------|--------|
| 38 | S2.9 | FUNC | Build AI content reformatter — 1 note → 5 platform versions | Foreman | deployed | ✅ CLOSED | 2026-03-09 |
| 39 | S2.10 | FUNC | Build 7-block daily summary — 0800 CST standup briefing | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 40 | S2.11 | FUNC | Build arc scoring — content vs thematic arc alignment | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 41 | S2.12 | SEC | AI output validation — sanitize all Claude-generated content | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 42 | S2.13 | SEC | AI response length enforcement — prevent token overflow | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 43 | S2.14 | FUNC | Build quick-publish panel — inline editor + platform toggles | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 44 | S2.15 | FUNC | Build 5-version preview — side-by-side platform preview | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 45 | S2.16 | FUNC | Build publish dispatch — one-click multi-platform post | Foreman | deployed | ✅ CLOSED | 2026-03-09 |
| 46 | S2.17 | FUNC | Build REST API endpoints — block data, feed items, publish actions | Foreman | deployed | ✅ CLOSED | 2026-03-09 |
| 47 | S2.18 | FUNC | Build RSS feed output — /feed/the-markdown for subscribers | DevOps | deployed | ✅ CLOSED | 2026-03-09 |
| 48 | S2.19 | SEC | CSRF protection on quick-publish actions | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 49 | S2.20 | SEC | Content escaping on social media output — XSS prevention | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 50 | S2.21 | SEC | Publish audit trail — log all social media dispatch events | Cyber Ops | deployed | ✅ CLOSED | 2026-03-09 |
| 51 | S2.22 | SEC | Rate limit handler — exponential backoff + queue | DevOps | deployed | ✅ CLOSED | 2026-03-09 |

---

## Sprint 2.5 — Integration Gate

**Status:** ✅ COMPLETE | **Tasks:** 6/6 closed
**Estimated:** ~4h | **Gate Criteria:** S2.5.1 + S2.5.2 must pass with zero failures before Sprint 3 begins — ✅ GATE PASSED
**Scope:** Core editorial pipeline only — social API verification deferred to Sprint 3.5
**Gate Result:** CONDITIONAL PASS — editorial chain 6 PASS / 2 PARTIAL (same as S1.5), security 6/6 PASS

| # | ID | Type | Task | Owner | Status |
|---|-----|------|------|-------|--------|
| 82 | S2.5.1 | VERIFY | Full editorial chain smoke test — 6 PASS, 2 PARTIAL (AI key + digest) | DevOps + Foreman | ✅ CLOSED 2026-03-10 |
| 83 | S2.5.2 | VERIFY | Security stack re-verification — 6/6 PASS at 74 active snippets | Cyber Ops | ✅ CLOSED 2026-03-10 |
| 84 | S2.5.3 | OPS | Snippet inventory — 85 total, 74 active, 0 errors, no priority conflicts | DevOps | ✅ CLOSED 2026-03-10 |
| 85 | S2.5.4 | OPS | REST endpoint health check — 6/6 endpoints healthy, all <2s | DevOps | ✅ CLOSED 2026-03-10 |
| 86 | S2.5.5 | OPS | RSS feed verification — valid RSS 2.0, permalink needs flush, no auto-discovery | DevOps | ✅ CLOSED 2026-03-10 |
| 87 | S2.5.6 | OPS | Operational Playbook updated for Sprint 3 (retro action B10) | Taskmaster | ✅ CLOSED 2026-03-10 |

---

## Sprint 3 — Scale & Polish

**Status:** 🔵 IN PROGRESS | **Tasks:** 12/19 closed | **Milestone:** Sprint 3 — Scale & Polish
**Estimated:** ~55h | **Started:** 2026-03-10
**Execution:** 3 waves — Wave 1 ✅ COMPLETE → Wave 2 (QA) ✅ COMPLETE → Wave 3 / Gate 7 (6 tasks, cyber + 1 SEC)
**Note:** S3.4, S3.7, and S2.3 moved to Sprint 3.5 (pay-to-play decision gate). CF-1 + CF-3 added from S2.5 retro.

### Wave 1 + Wave 2 — Visual, Infrastructure, QA ✅ 12/12 CLOSED

| # | ID | Type | Task | Owner | Status | Closed |
|---|-----|------|------|-------|--------|--------|
| 52 | S3.1 | FUNC | Build 6 Canva domain templates — branded visual cards | Taskmaster | ✅ CLOSED | 2026-03-12 |
| 53 | S3.2 | FUNC | Configure Canva MCP — auto-generate cards from templates | DevOps | ✅ CLOSED | 2026-03-12 |
| 54 | S3.3 | FUNC | Build archive page — historical editions with date/domain filter | DevOps | ✅ CLOSED | 2026-03-12 |
| 56 | S3.5 | FUNC | Build feed health monitor — detect broken feeds + alerts | DevOps | ✅ CLOSED | 2026-03-11 |
| 57 | S3.6 | FUNC | Configure subdomain — markdown.justin-kuiper.com | Taskmaster | ✅ CLOSED | 2026-03-12 |
| 59 | S3.8 | FUNC | Build about page update — baseball card refresh | Taskmaster | ✅ CLOSED | 2026-03-12 |
| 60 | S3.9 | SEC | GitLab CI/CD pipeline security — protected branches, signed commits | Cyber Ops | ✅ CLOSED | 2026-03-11 |
| 61 | S3.10 | SEC | WordPress plugin audit — remove unused, update all, allowlist | Cyber Ops | ✅ CLOSED | 2026-03-11 |
| 62 | S3.11 | SEC | Database backup automation — daily encrypted backups | DevOps | ✅ CLOSED | 2026-03-11 |
| 64 | S3.13 | FUNC | Performance optimization — caching, lazy load, CDN evaluation | DevOps | ✅ CLOSED | 2026-03-12 |
| 65 | S3.14 | FUNC | Mobile responsive QA — test all pages on 3 breakpoints | Taskmaster | ✅ CLOSED | 2026-03-12 |
| 66 | S3.15 | FUNC | SEO configuration — meta tags, OG tags, structured data | DevOps | ✅ CLOSED | 2026-03-12 |

### Wave 3 — Gate 6 Remaining + Gate 7 (Final Cyber Gate) — 0/7 OPEN

**⚠ S3.6 Scope Impact (2026-03-12):** Sprint 3.6 deployed 4 snippets (108↑, 109↑, 119+, 120+) including the first client-side JS injection (snippet 120) and an external resource dependency (Google Fonts in snippet 108). Tasks S3.16, S3.19, S3.20, and S3.21 have updated scope notes below.

| # | ID | Type | Task | Owner | Status |
|---|-----|------|------|-------|--------|
| 63 | S3.12 | SEC | File permission hardening — wp-content, uploads, themes | Cyber Ops | ⬜ OPEN (High) |
| 67 | S3.16 | SEC | Penetration test — OWASP Top 10 scan on all endpoints | Cyber Ops | ⬜ OPEN |
| 68 | S3.17 | SEC | Incident response plan — document response procedures | Cyber Ops | ⬜ OPEN (Medium) |
| 69 | S3.18 | SEC | Security monitoring setup — alerts for suspicious activity | Cyber Ops | ⬜ OPEN (Medium) |
| 70 | S3.19 | SEC | Final cyber gate review — all 7 gates pass | Cyber Ops | ⬜ OPEN |
| 71 | S3.20 | SEC | OPSEC review — verify no secrets in repos, logs, or public pages | Cyber Ops | ⬜ OPEN (High) |
| 72 | S3.21 | SEC | Documentation — security architecture doc, runbooks, credential inventory | Overwatch | ⬜ OPEN |

**S3.6 Scope Notes:**
- **S3.16 (Pen Test):** Must include snippet 120 JS injection pattern — verify `data-domain` attribute setting from `.md-block-domain` text cannot be exploited for DOM XSS. Test that injected attributes don't enable CSS injection or attribute-based attacks. Snippet inventory now 120 total (76 active).
- **S3.19 (Final Gate Review):** Gate review must cover all 4 S3.6 snippets. Snippet 120 introduces first client-side JS in the snippet stack — new pattern requires explicit sign-off. Verify no regression from S3.6 CSS `!important` overrides on theme security headers.
- **S3.20 (OPSEC Review):** Google Fonts import (snippet 108) pings `fonts.googleapis.com` and `fonts.gstatic.com` on every page 1077 load — verify referrer policy, confirm no PII leakage via font request headers. Check that no design tokens or CSS variable names leak sensitive architecture info.
- **S3.21 (Documentation):** Security architecture doc must reflect: updated snippet inventory (120 total), JS injection pattern in snippet 120, external font dependency chain, and the `data-domain` attribute mapping logic.

---

## Sprint 3.5 — Stabilization & Markdown Foundation

**Status:** ✅ COMPLETE | **Tasks:** 9/9 closed | **Milestone:** Sprint 3.5 — Stabilization & Markdown Foundation (GitLab)
**Scope:** Bug fixes from Wave 1/2 QA (Issues #82–#88) + The Markdown editorial page build + QA verification
**Executed:** Between S3 Wave 2 and Wave 3

| # | ID | Type | Task | Owner | Status | Closed |
|---|-----|------|------|-------|--------|--------|
| 82 | S3.5-BF01 | BUG-P1 | Fix About page horizontal overflow on mobile | DevOps | ✅ CLOSED | 2026-03-12 |
| 83 | S3.5-BF02 | BUG-P2 | Fix RSS feed — returns 0 items | DevOps | ✅ CLOSED | 2026-03-12 |
| 84 | S3.5-BF03 | BUG-P2 | Fix archive pagination — limit visible page buttons | DevOps | ✅ CLOSED | 2026-03-12 |
| 85 | S3.5-BF04 | BUG-P2 | Fix mobile nav — enforce dark theme background | DevOps | ✅ CLOSED | 2026-03-12 |
| 86 | S3.5-BF05 | BUG-P2 | Fix feed item pages — add H1 article headline | DevOps | ✅ CLOSED | 2026-03-12 |
| 87 | S3.5-BF06 | BUG-P3 | Add site footer to all pages | DevOps | ✅ CLOSED | 2026-03-12 |
| 88 | S3.5-BF07 | BUG-P3 | Fix featured image white background on feed items | DevOps | ✅ CLOSED | 2026-03-12 |
| 89 | S3.5-MP01 | FUNC | Build The Markdown editorial page — Block layout | DevOps | ✅ CLOSED | 2026-03-12 |
| 90 | S3.5-QA01 | FUNC | QA Sprint 3.5 — verify bug fixes and Markdown page | Taskmaster | ✅ CLOSED | 2026-03-12 |

---

## Sprint 3.6 — UI Drift Fixes (Prototype → Production Alignment)

**Status:** ✅ COMPLETE | **Tasks:** 5/5 closed | **Milestone:** Sprint 3.6 — UI Drift Fixes
**Trigger:** Visual audit revealed 8 deltas between GitLab Pages prototype and WordPress production
**Executed:** 2026-03-12 | **Estimated:** ~3h

| # | ID | Type | Task | Owner | Snippet | Status | Closed |
|---|-----|------|------|-------|---------|--------|--------|
| 91 | S3.6-D01 | FUNC | Full-width breakout — override Hever 750px content constraint on page 1077 | DevOps | #108 (updated) | ✅ CLOSED | 2026-03-12 |
| 92 | S3.6-D02 | FUNC | Prototype font import — Rajdhani, Source Sans Pro, JetBrains Mono via Google Fonts | DevOps | #108 (updated) | ✅ CLOSED | 2026-03-12 |
| 93 | S3.6-D04 | FUNC | Design token CSS variables — 6 accent colors, 3 font families, backgrounds, borders | DevOps | #108 (updated) | ✅ CLOSED | 2026-03-12 |
| 94 | S3.6-D05 | FUNC | Per-category accent colors on blocks — AI/Cyber/Innovation/FNW/Space/Digital | DevOps | #109 (updated) + #120 (new) | ✅ CLOSED | 2026-03-12 |
| 95 | S3.6-D07 | FUNC | Hide WordPress Share/Like widgets on The Markdown page | DevOps | #119 (new) | ✅ CLOSED | 2026-03-12 |

**Snippets Deployed:**
- **#108** `S3.5-W2-M09a Markdown Styles — Layout` — UPDATED with full-width breakout, Google Fonts, design tokens
- **#109** `S3.5-W2-M09b Markdown Styles — Cards` — UPDATED with per-category CSS variables and prototype fonts
- **#119** `S3.6-D07 Markdown — Hide WP Widgets` — NEW, hides Jetpack sharing/likes on page 1077
- **#120** `S3.6-D05b Markdown — Block Domain Attributes` — NEW, JS injects data-domain attrs for per-category colors

**Remaining Deltas (deferred to Sprint 3.7 or manual):**
- D-03: Block 00 hero image (placeholder in both — needs real image asset)
- D-06: Commentary card "JK" avatar styling (minor refinement)
- D-08: Footer bottom spacing (minor, cascaded from D-01 fix)

---

## Sprint 3.7 — Repo Sync & Production Hotfix

**Status:** ✅ COMPLETE | **Tasks:** 5/5 closed
**Type:** Maintenance & Hotfix | **Executed:** 2026-03-12 (single session)
**Decisions:** DR-0028 (nav fix method), DR-0029 (API username h3ndriksj), DR-0030 (.gitignore)

| # | ID | Type | Task | Owner | Status | Closed |
|---|-----|------|------|-------|--------|--------|
| 96 | BF-08 | HOTFIX | Fix nav menu item #78 — repoint from markdown.justin-kuiper.com to /the-markdown/ | Taskmaster | ✅ CLOSED | 2026-03-12 |
| 97 | REPO-01 | MAINT | Pull 14 remote commits, resolve 7 merge conflicts from folder reorganization | DevOps | ✅ CLOSED | 2026-03-12 |
| 98 | REPO-02 | MAINT | Commit full portfolio restructure + all QA artifacts (129 files) | DevOps | ✅ CLOSED | 2026-03-12 |
| 99 | REPO-03 | MAINT | Push to GitLab origin/main | DevOps | ✅ CLOSED | 2026-03-12 |
| 100 | AUTH-01 | MAINT | Validate new application password with correct username (h3ndriksj) | DevOps | ✅ CLOSED | 2026-03-12 |

**Key Outcomes:**
- P1 nav link bug (NXDOMAIN) fixed < 5 min from detection
- API username corrected: `h3ndriksj` replaces `yetisecurity` (DR-0029)
- 129 files committed to GitLab, HEAD: `e947992`
- `.gitignore` added for `.claude/`, `.DS_Store`, `__pycache__/` (DR-0030)

---

## Sprint 3.8 — Editorial Approval Workflow

**Status:** ✅ COMPLETE | **Tasks:** 8/8 closed | **Milestone:** Sprint 3.8 — Editorial Approval Workflow
**Sprint Goal:** Human-in-the-loop editorial approval gate between AI curation and The Markdown's live page
**Est. Effort:** 6–7h across 8 snippets | **Executed:** 2026-03-12 (Wave 1 + Wave 2)
**Architecture:** RSS → Claude Scoring → Draft Builder → Email Digest → Admin Approval UI → Preference Logger → Published Board → Shortcode renders

### Wave 1 — Foundation (No Dependencies) ✅ 3/3 CLOSED

| # | ID | Type | Task | Owner | Snippet IDs | Status | Closed |
|---|-----|------|------|-------|-------------|--------|--------|
| 101 | S3.8.1 | FUNC | Board Data Model — 2-layer wp_options (draft/published), helper functions | DevOps | WP#122 (S121) | ✅ CLOSED | 2026-03-12 |
| 102 | S3.8.6 | FUNC | Editorial Shortcode Patch — read from published board, fallback to live query | DevOps | WP#123 (S126) | ✅ CLOSED | 2026-03-12 |
| 103 | S3.8.7 | FUNC | Hero Image Pipeline — OG scrape at ingest, `_jk_hero_image` meta, sentinel bridge | DevOps | WP#124 (S127) | ✅ CLOSED | 2026-03-12 |

**Wave 1 QA:** ALL PASS — 6 ACs per task verified. Schema discovery: `source_url` confirmed. Hero bridge uses sentinel ID `-9999` filter. No regressions.

### Wave 2 — Pipeline + UI (Depends on Wave 1) ✅ 4/4 CLOSED

| # | ID | Type | Task | Owner | Snippet IDs | Status | Closed |
|---|-----|------|------|-------|-------------|--------|--------|
| 104 | S3.8.2 | FUNC | Draft Builder — cron 0800 ET + on-demand, 48h window, 19-slot proposal | DevOps | WP#126 (S122) | ✅ CLOSED | 2026-03-12 |
| 105 | S3.8.3 | FUNC | Admin Approval UI — reject/move/swap/publish/refresh + topic steering | DevOps | WP#128+129 (S123a/b) | ✅ CLOSED | 2026-03-12 |
| 106 | S3.8.4 | FUNC | Email Digest — HTML digest to h3ndriks.j@gmail.com after cron builds | DevOps | WP#130 (S124) | ✅ CLOSED | 2026-03-12 |
| 107 | S3.8.5 | FUNC | Preference Logger — delta tracking, 90-day rolling log, 30-day weight computation | DevOps | WP#127 (S125) | ✅ CLOSED | 2026-03-12 |

**Wave 2 QA:** All 5 snippets ACTIVE (IDs 126–130, ~710 lines). Draft builder: 200 items considered, 19/19 slots filled, 15 candidates in pool. Known limitations: all items score=1 (Claude API key not in vault), only 2 hero images found.

### Hotfix S3.8-HF01 — Production QA Findings (2026-03-13)

| # | ID | Type | Task | Owner | Snippet | GitLab | Status |
|---|-----|------|------|-------|---------|--------|--------|
| 109 | HF01-A | BUG | Hero image renders placeholder on live page — Jetpack Photon breaks sentinel bridge | DevOps | WP#114 | #110 | ✅ CLOSED | 2026-03-13 |
| 110 | HF01-B | UX | Admin UI missing Promote-to-Lead controls, no publish confirmation | DevOps | WP#128 | #111 | ✅ CLOSED | 2026-03-13 |
| 111 | HF01-C | BUG | Block numbers (01-06 + "BLOCK 00") visible on public page | DevOps | WP#114, WP#115 | #112 | ✅ CLOSED | 2026-03-13 |
| 112 | HF01-D | BUG | "Commentary pending" placeholder cards visible on public page | DevOps | WP#111 | #113 | ✅ CLOSED | 2026-03-13 |
| 113 | HF01-E | UX | Move to occupied slot needs swap/replace options (non-blocking modal) | DevOps | WP#128, WP#129 | #114 | ✅ CLOSED | 2026-03-13 |

**Root Causes:**
- HF01-A: WordPress.com Jetpack Photon CDN intercepts `image_downsize` filter before sentinel `-9999` bridge can resolve. Fix: direct `_jk_hero_image` meta fallback in Block 00 renderer.
- HF01-B: Generic Move dropdown requires knowing "00" = lead slot. No visual distinction for Box 00. No publish confirmation dialog.
- HF01-C: Block numbers were internal editorial identifiers leaking to public page. Removed from S114 (hero badge) and S115 (grid headers).
- HF01-D: Commentary card rendered placeholder text when `jk_commentary` meta was empty. Fixed with early `return;` in S111.
- HF01-E: Move handler rejected occupied targets with no options. Added `slot_occupied` structured error + inline modal with Swap/Replace/Cancel. Replaced `prompt()` which froze Chrome.
**DevOps Prompt:** `02 DevOps/Prompts/Sprint3.8_Hotfix_DevOps_CODE.md`

### Operational — 1/1 CLOSED

| # | ID | Type | Task | Owner | Status |
|---|-----|------|------|-------|--------|
| 108 | S3.8.8 | OPS | Operational Playbook update — snippet inventory, slot addressing, editorial workflow + Snippet Integrity Protocol (OW-0029) | Taskmaster | ✅ CLOSED | 2026-03-13 |

**S3.8 Snippet Inventory:**

| API ID | Logical ID | Wave | Task | Description | Lines |
|--------|-----------|------|------|-------------|-------|
| 122 | S121 | W1 | S3.8.1 | Board Data Model + Helpers | ~101 |
| 123 | S126 | W1 | S3.8.6 | Editorial Shortcode Patch | ~98 |
| 124 | S127 | W1 | S3.8.7 | Hero Image Pipeline | ~82 |
| 126 | S122 | W2 | S3.8.2 | Draft Builder (Cron + On-Demand) | ~112 |
| 127 | S125 | W2 | S3.8.5 | Preference Logger & Learning | ~130 |
| 128 | S123a | W2 | S3.8.3 | Admin Approval UI (Render + Conflict Modal) | ~211 |
| 129 | S123b | W2 | S3.8.3 | Admin Approval AJAX Handlers (swap/replace) | ~297 |
| 130 | S124 | W2 | S3.8.4 | Email Digest Notification | ~93 |

**Manual Verification Needed (Yeti + Taskmaster):**
1. Admin UI visual check — wp-admin → Feed Items → Editorial Board
2. Reject flow — click Reject, verify auto-fill from pool
3. Move flow — move item between slots via dropdown
4. Publish flow — click Publish Board, verify page updates
5. Email digest — trigger cron or manual, check inbox
6. Share buttons — X/LinkedIn/Instagram icons, verify URLs
7. Mobile layout — admin page on phone (768px breakpoint)
8. Swap/Replace — move to occupied slot, test Swap Positions and Replace (to pool) buttons

---

## Sprint 4 — Pay-to-Play Decision Gate

**Status:** ⬜ NOT STARTED | **Tasks:** 0/7 closed
**Gate:** GO/NO-GO per feature — cost/benefit decision before execution
**Note:** If social API paid tiers aren't worth it, Yeti posts manually. Social links under articles maintain the ecosystem.

### Feature Tasks (Require GO/NO-GO)

| # | ID | Type | Task | Owner | Cost Gate | Status |
|---|-----|------|------|-------|-----------|--------|
| 32 | S2.3 | FUNC | Build Instagram API integration — Graph API via Facebook | DevOps | Meta App Review / platform fees | ⬜ OPEN (carry-forward) |
| 55 | S3.4 | FUNC | Build analytics dashboard — cross-platform engagement tracking | DevOps | Paid API tiers (X, LinkedIn, YouTube) | ⬜ OPEN (moved from S3) |
| 58 | S3.7 | FUNC | Build social wall page — aggregated cross-platform feed | DevOps | Same paid API access as S3.4 | ⬜ OPEN (moved from S3) |

### Verification & Decision Tasks

| # | ID | Type | Task | Owner | Status |
|---|-----|------|------|-------|--------|
| 88 | S3.5.1 | VERIFY | Social API publish chain — OAuth → token refresh → reformat → post → audit | DevOps + Foreman | ⬜ OPEN |
| 89 | S3.5.2 | VERIFY | AI reformatter chain — feed item → 5 platform versions → preview → quick-publish | DevOps | ⬜ OPEN |
| 90 | S3.5.3 | VERIFY | Publish dispatch end-to-end — select → edit → toggle → dispatch → confirm → audit | Foreman | ⬜ OPEN |
| 91 | S3.5.4 | OPS | Cost/benefit analysis — per-platform cost, capability, alternative, recommendation | Taskmaster | ⬜ OPEN |

---

## Effort Summary

| Sprint | Tasks | Closed | Open | Status |
|--------|-------|--------|------|--------|
| S0 — Hardening | 7 | 7 | 0 | ✅ COMPLETE (closed) |
| S1 — Foundation | 23 | 23 | 0 | ✅ COMPLETE (closed) |
| S1.5 — Integration Gate | 8 | 8 | 0 | ✅ COMPLETE (closed) |
| S2 — Social & Publishing | 22 | 21 | 1 | 🔶 21/22 (S2.3 deferred) |
| S2.5 — Integration Gate | 6 | 6 | 0 | ✅ COMPLETE |
| S3 — Scale & Polish | 19 | 12 | 7 | 🔵 Wave 3 remaining |
| S3.5 — Stabilization | 9 | 9 | 0 | ✅ COMPLETE |
| S3.6 — UI Drift Fixes | 5 | 5 | 0 | ✅ COMPLETE |
| S3.7 — Repo Sync & Hotfix | 5 | 5 | 0 | ✅ COMPLETE |
| S3.8 — Editorial Approval | 8 | 8 | 0 | ✅ COMPLETE |
| S3.8-HF01 — Production QA | 5 | 5 | 0 | ✅ COMPLETE |
| S4 — Pay-to-Play Gate | 7 | 0 | 7 | ⬜ NOT STARTED |
| **Total** | **124** | **108** | **16** | **87% complete** |

---

## Pipelines

| Pipeline | Status | Branch | Date |
|----------|--------|--------|------|
| #2376500310 | ✅ success | main | 2026-03-10 |
| #2376383924 | ✅ success | main | 2026-03-10 |
| #2376351326 | ✅ success | main | 2026-03-10 |
| #2376319576 | ✅ success | main | 2026-03-10 |
| #2374274359 | ✅ success | main | 2026-03-10 |

---

*Full reconciliation by Taskmaster — 2026-03-13. S3.8.8 closed (Snippet Integrity Protocol execution — OW-0029/DR-0032). S3.8 milestone COMPLETE. GitLab is the source of truth.*
