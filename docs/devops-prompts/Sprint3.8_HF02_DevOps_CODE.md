# DevOps Code Prompt — S3.8-HF02: Publishing Queue & Sequential Review

**Sprint:** 3.8 Hotfix 02
**Owner:** DevOps
**Requested by:** Yeti
**Priority:** High
**Estimated:** ~4h across 2–3 snippets
**Architecture:** Extends Layer 10 — Editorial Approval Workflow (snippets 122, 128, 129)

---

## Context

The Editorial Board admin UI (wp-admin → Feed Items → Editorial Board) currently shows all 19 slots at once. The "Publish Board" button publishes everything in the draft board to the live page in one action.

Yeti wants a **sequential review workflow with a publishing queue**:

1. Walk through each box one at a time (Box 00 → Box 01 → … → last populated slot)
2. For each box: review the item, check the hero image, decide yes/no
3. Click **"Submit to Publishing Queue"** → confirmation dialog → item is queued
4. Advance to the next box automatically
5. At the end (or at any time), hit a green **"Publish Board"** button at the top to push all queued items live
6. Can pull items **out** of the queue before publishing
7. Can still skip items without queuing them

This is a UX enhancement to existing snippets, not a new pipeline.

---

## Boot Sequence

1. Read `Operational_Playbook.md` — Section 4 (snippet inventory), Section 6 (deployment procedure)
2. Read `Snippet_Integrity_Taskmaster_Directive.md` — follow hotfix checklist
3. Request credentials from Yeti: WordPress Application Password (username: `h3ndriksj`)
4. Pull current source for snippets **128**, **129**, and **122** via Code Snippets REST API:
   ```
   GET /wp-json/code-snippets/v1/snippets/128
   GET /wp-json/code-snippets/v1/snippets/129
   GET /wp-json/code-snippets/v1/snippets/122
   ```
5. Read the live code before making any changes — do NOT work from memory or cached versions

---

## Architecture Decisions

**Queue state storage:** Add a `queued` boolean flag to each slot in the existing `jk_editorial_draft` wp_options array. This avoids creating a third wp_options row and keeps the data model in snippet 122 clean. When an item is queued, `$slot['queued'] = true`. Default is `false` (or absent).

**Publish behavior change:** The existing "Publish Board" action (in snippet 129) currently copies the entire draft board to `jk_editorial_published`. Modify it to **only copy slots where `queued === true`**. Un-queued slots retain their current published state (don't overwrite with empty).

**UI pattern:** The sequential review is a **JS overlay/modal within the existing admin page**, not a separate page. This keeps it inside the existing nonce context and avoids routing complexity. The full board view remains accessible — sequential review is an additional mode.

**Snippet split:** Follow the existing split pattern (128 = render/UI, 129 = AJAX handlers). Queue/unqueue AJAX actions go in 129. Sequential review JS/HTML goes in 128. If 128 exceeds ~250 lines after changes, extract the sequential review UI into a new snippet (131) scoped to `admin`.

---

## Task 1 — Data Model Update (Snippet 122)

**File:** Board Data Model + Helpers (WP API ID: 122, Logical: S121)
**Current size:** ~101 lines

### Changes

Add a helper function for queue operations:

```php
/**
 * Toggle queue status for a board slot.
 * @param string $slot Slot key (e.g., 'box_00', 'box_01')
 * @param bool $queued True to queue, false to unqueue
 * @return bool Success
 */
function jk_queue_board_slot( $slot, $queued = true ) {
    $board = jk_get_draft_board();
    if ( ! isset( $board[ $slot ] ) || empty( $board[ $slot ]['post_id'] ) ) {
        return false;
    }
    $board[ $slot ]['queued'] = (bool) $queued;
    return jk_save_draft_board( $board );
}

/**
 * Get all queued slots from draft board.
 * @return array Associative array of queued slots only
 */
function jk_get_queued_slots() {
    $board = jk_get_draft_board();
    return array_filter( $board, function( $slot ) {
        return ! empty( $slot['post_id'] ) && ! empty( $slot['queued'] );
    });
}

/**
 * Clear all queue flags (reset after publish).
 */
function jk_clear_queue_flags() {
    $board = jk_get_draft_board();
    foreach ( $board as $key => &$slot ) {
        unset( $slot['queued'] );
    }
    return jk_save_draft_board( $board );
}
```

### Modify existing `jk_publish_board()`

The current function copies the full draft board to `jk_editorial_published`. Change it to:

1. Get the queued slots via `jk_get_queued_slots()`
2. Get the current published board
3. **Merge** queued slots into the published board (overwrite only those slot keys)
4. Save the merged result as `jk_editorial_published`
5. Call `jk_clear_queue_flags()` after successful publish
6. Return the count of published slots

```php
// REPLACE the existing jk_publish_board() body with:
function jk_publish_board() {
    $queued = jk_get_queued_slots();
    if ( empty( $queued ) ) {
        return 0; // nothing to publish
    }
    $published = get_option( 'jk_editorial_published', array() );
    foreach ( $queued as $slot_key => $slot_data ) {
        $clean = $slot_data;
        unset( $clean['queued'] ); // don't persist queue flag to published
        $published[ $slot_key ] = $clean;
    }
    update_option( 'jk_editorial_published', $published );
    jk_clear_queue_flags();
    // Fire preference logger (existing hook)
    do_action( 'jk_board_published', $published );
    return count( $queued );
}
```

### Acceptance Criteria

- [ ] `jk_queue_board_slot('box_00', true)` sets `queued = true` on Box 00
- [ ] `jk_queue_board_slot('box_00', false)` removes queue flag
- [ ] `jk_get_queued_slots()` returns only slots with `queued === true` and a valid `post_id`
- [ ] `jk_publish_board()` only publishes queued slots, not the entire board
- [ ] Un-queued slots in the published board are NOT overwritten (existing published state preserved)
- [ ] Queue flags are cleared after publish
- [ ] Preference logger still fires on publish

---

## Task 2 — AJAX Handlers (Snippet 129)

**File:** Admin Approval AJAX Handlers (WP API ID: 129, Logical: S123b)
**Current size:** ~297 lines (largest in S3.8 stack — DR-0024 exception)

### New AJAX Actions

Register two new actions:

#### `jk_queue_slot`

```php
add_action( 'wp_ajax_jk_queue_slot', 'jk_handle_queue_slot' );
function jk_handle_queue_slot() {
    check_ajax_referer( 'jk_editorial_nonce', 'nonce' );

    if ( ! current_user_can( 'edit_posts' ) ) {
        wp_send_json_error( array( 'code' => 'unauthorized' ) );
    }

    $slot   = sanitize_text_field( $_POST['slot'] ?? '' );
    $action = sanitize_text_field( $_POST['queue_action'] ?? 'queue' ); // 'queue' or 'unqueue'

    if ( ! preg_match( '/^box_\d{2}$/', $slot ) ) {
        wp_send_json_error( array( 'code' => 'invalid_slot', 'message' => 'Invalid slot format' ) );
    }

    $queued = ( $action === 'queue' );
    $result = jk_queue_board_slot( $slot, $queued );

    if ( $result ) {
        wp_send_json_success( array(
            'slot'    => $slot,
            'queued'  => $queued,
            'message' => $queued ? 'Added to publishing queue' : 'Removed from publishing queue',
            'queue_count' => count( jk_get_queued_slots() ),
        ) );
    } else {
        wp_send_json_error( array( 'code' => 'queue_failed', 'message' => 'Slot is empty or save failed' ) );
    }
}
```

#### Modify existing `jk_handle_publish_board`

Update the publish handler response to include the count:

```php
// In the existing publish handler, replace the success response:
$count = jk_publish_board();
if ( $count > 0 ) {
    wp_send_json_success( array(
        'message'         => sprintf( '%d items published to The Markdown', $count ),
        'published_count' => $count,
    ) );
} else {
    wp_send_json_error( array(
        'code'    => 'empty_queue',
        'message' => 'No items in publishing queue. Review and queue items first.',
    ) );
}
```

### Size Check

Snippet 129 is already at ~297 lines (DR-0024 exception). Adding `jk_handle_queue_slot` adds ~30 lines. If total exceeds ~330 lines, extract the queue handler into a new snippet (131, scope: `admin`, name: `S3.8-HF02 Queue AJAX Handler`). Prefer extraction over bloat.

### Acceptance Criteria

- [ ] `wp_ajax_jk_queue_slot` registered and nonce-protected
- [ ] Queue action sets `queued = true`, unqueue sets `queued = false`
- [ ] Response includes updated `queue_count` for UI badge update
- [ ] Invalid slot format returns structured error
- [ ] Unauthorized users get 403
- [ ] Publish action returns `empty_queue` error if nothing is queued (prevents accidental blank publish)
- [ ] Publish action returns count of published items on success

---

## Task 3 — Admin UI: Sequential Review Mode (Snippet 128)

**File:** Admin Approval UI — Render + Conflict Modal (WP API ID: 128, Logical: S123a)
**Current size:** ~211 lines

This is the main UI change. Add a **Review Mode** overlay and queue status indicators to the existing board view.

### 3A — Queue Status on Board View (always visible)

On the existing board grid, add visual indicators:

- **Queued items** get a green left border + small "QUEUED" badge (top-right of card)
- **Un-reviewed items** have no badge (default state)
- **Green "Publish Board" button** at the top of the page, showing count: `Publish Board (7 queued)`. Disabled (greyed out) when queue is empty (0 queued). Replaces or sits next to the existing Publish Board button.
- **"Start Review" button** next to the Publish button — enters sequential mode

### 3B — Sequential Review Overlay

When "Start Review" is clicked, render a **full-width overlay/modal** inside the admin page:

```
┌──────────────────────────────────────────────────────┐
│  REVIEWING: Box 00 — LEAD                    3 / 19  │
│  ─────────────────────────────────────────────────── │
│                                                       │
│  [Hero Image]                                         │
│                                                       │
│  HEADLINE: Fed Cuts Interest Rates by 50 Basis...     │
│  SOURCE: reuters.com                                  │
│  DOMAIN: Finance & World News                         │
│  SCORE: 8.4                                           │
│  INGESTED: 2026-03-14 06:12 CST                      │
│                                                       │
│  ┌─────────────────────┐  ┌──────────┐  ┌─────────┐ │
│  │ ✅ Submit to Queue   │  │  Skip ➡️  │  │ ❌ Exit │ │
│  └─────────────────────┘  └──────────┘  └─────────┘ │
│                                                       │
│  Queue: ██░░░░░░░░░░░░░░░░░ 3/19                     │
└──────────────────────────────────────────────────────┘
```

**Overlay behavior:**

1. **Entry:** Click "Start Review" → overlay opens at Box 00 (the lead slot)
2. **Submit to Queue:** Confirmation dialog ("Queue this item for publishing?") → on Yes, fires `jk_queue_slot` AJAX → green checkmark animation → auto-advance to next populated box
3. **Skip:** Advance to next populated box without queuing. Item stays un-queued.
4. **Already queued:** If returning to an already-queued item (via Back button or re-entering review), show "Remove from Queue" instead of "Submit to Queue"
5. **Back button:** Navigate to previous box (don't auto-advance past items, allow going back)
6. **Progress bar:** Visual bar + "3/19" counter showing position in the board
7. **Exit:** Close overlay, return to full board view. Queue state persists — items already queued stay queued.
8. **Empty slots:** Skip automatically — don't show empty boxes in the review sequence
9. **End of review:** After the last populated box, show summary: "Review complete. X items queued. Ready to publish?" with a green Publish button and a "Back to Board" option.

### 3C — Confirmation Dialogs

Use inline modals (same pattern as HF01-E swap/replace modal). Do NOT use `prompt()` or `confirm()` — they freeze Chrome on WordPress.com.

- **Queue confirmation:** "Queue [headline truncated to 60 chars] for publishing?" → [Queue] [Cancel]
- **Unqueue confirmation:** "Remove [headline] from publishing queue?" → [Remove] [Cancel]
- **Publish confirmation (green button):** "Publish X items to The Markdown? This will update the live page." → [Publish Now] [Cancel]

### 3D — CSS

Keep inline (same pattern as existing S128 styles). Dark theme consistent with The Markdown brand:

- Overlay background: `rgba(13, 17, 23, 0.95)` (matches `#0d1117`)
- Card background: `#1a1a2e`
- Queue badge: `#22c55e` (green)
- Submit button: `#22c55e` background, white text
- Skip button: `#374151` (neutral gray)
- Exit button: `#ef4444` (red)
- Progress bar fill: `#06b6d4` (brand cyan)
- All text: white/light gray

### Size Management

The sequential review overlay will add significant HTML/JS. Expected addition: ~150–200 lines. Options:

**Option A (preferred):** Extract the sequential review UI into a **new snippet 131** (scope: `admin`, name: `S3.8-HF02 Sequential Review UI`). Keep snippet 128 for the board grid view + queue badges. Snippet 131 handles the overlay, navigation logic, and AJAX calls. Communicate via shared nonce and DOM events.

**Option B:** If the review JS is compact enough (<120 lines), keep it in 128. Only do this if 128 stays under ~330 lines total.

**Decision: Use Option A** — extract to snippet 131. This follows DR-0016 (Lego block architecture) and avoids pushing 128 into monolith territory.

### Acceptance Criteria

- [ ] Green "Publish Board (X queued)" button visible on board view, disabled when queue empty
- [ ] "Start Review" button enters sequential overlay mode
- [ ] Overlay shows one box at a time with hero image, headline, source, domain, score, ingest date
- [ ] "Submit to Queue" fires AJAX with confirmation dialog (no `prompt()`/`confirm()`)
- [ ] "Skip" advances without queuing
- [ ] "Remove from Queue" available for already-queued items
- [ ] Back navigation works
- [ ] Empty slots are skipped in the sequence
- [ ] Progress bar updates correctly
- [ ] End-of-review summary shows queue count with Publish option
- [ ] Publish button fires existing publish handler (modified for queue-only behavior)
- [ ] Queue state persists if overlay is exited and re-entered
- [ ] All AJAX calls use existing `jk_editorial_nonce`
- [ ] Dark theme styling matches The Markdown brand spec
- [ ] Mobile responsive at 768px breakpoint (stacked layout)

---

## Snippet Inventory (Expected After HF02)

| API ID | Logical ID | Scope | Change | Description |
|--------|-----------|-------|--------|-------------|
| 122 | S121 | global | MODIFIED | + queue helpers, modified `jk_publish_board()` |
| 128 | S123a | admin | MODIFIED | + queue badges on board view, + "Start Review" button |
| 129 | S123b | admin | MODIFIED | + `jk_queue_slot` AJAX handler, modified publish handler |
| 131 (new) | S128 | admin | NEW | Sequential Review overlay UI + navigation JS |

---

## Deployment Order

1. **Snippet 122** first (data model helpers must exist before AJAX handlers call them)
2. **Snippet 129** second (AJAX handlers depend on 122 helpers)
3. **Snippet 131** third (new — deploy INACTIVE, test, then activate)
4. **Snippet 128** last (UI references AJAX actions and new snippet's DOM)

Deploy each via REST API:
```
PUT /wp-json/code-snippets/v1/snippets/{id}
Auth: Basic Auth (h3ndriksj + app password)
```

For new snippet 131:
```
POST /wp-json/code-snippets/v1/snippets
Body: { "name": "S3.8-HF02 Sequential Review UI", "code": "...", "priority": 10, "scope": "admin", "active": false }
```

---

## Integrity Protocol (Mandatory)

Per `Snippet_Integrity_Taskmaster_Directive.md`:

- [ ] Compute SHA-256 hash for all modified/new snippets after deployment
- [ ] Update wiki Snippet Registry with new hashes
- [ ] Log changes in wiki Change Log: `2026-03-14 | S3.8-HF02 | MODIFIED 122, 128, 129 | NEW 131 | Publishing queue + sequential review`
- [ ] Update wiki Home dashboard snippet count
- [ ] No `eval()`, `exec()`, `system()`, `passthru()` in any code
- [ ] All AJAX handlers use `check_ajax_referer()`
- [ ] No hardcoded secrets or tokens

---

## Constraints

- **WordPress.com platform** — no filesystem access, WAF active
- **Lego block pattern** (DR-0016) — new snippet 131 targets <200 lines
- **No `prompt()` or `confirm()`** — use inline modals (learned from HF01-E)
- **Nonce reuse** — use existing `jk_editorial_nonce` from snippet 128. Do NOT create a second nonce.
- **Preference Logger compatibility** — `do_action('jk_board_published')` must still fire so snippet 127 logs the delta
- **REST API first** (Rank 1 tool) — deploy and test via API, browser only for visual QA

---

## Testing Checklist (DevOps Self-QA)

1. Open wp-admin → Feed Items → Editorial Board
2. Verify board loads with no queue badges (clean state)
3. Click "Start Review" — overlay opens at Box 00
4. Submit Box 00 to queue → confirmation dialog → confirm → advances to next box
5. Skip Box 01 → advances without queuing
6. Go back to Box 01 → no queue badge. Go forward to Box 02
7. Queue Box 02 → exit overlay
8. Verify board view shows green badges on Box 00 and Box 02 only
9. Verify green button says "Publish Board (2 queued)"
10. Re-enter review → Box 00 shows "Remove from Queue" instead of "Submit to Queue"
11. Remove Box 00 from queue → button says "Publish Board (1 queued)"
12. Click Publish Board → confirmation dialog → confirm
13. Verify live page (`justin-kuiper.com/the-markdown/`) updated with only Box 02's item
14. Verify previously published items in other slots were NOT overwritten
15. Verify queue is cleared after publish (no green badges remain)
16. Mobile check at 768px — overlay stacks correctly

---

*Prompt written by Taskmaster — 2026-03-14. Ref: Sprint_Tracker.md → S3.8-HF02.*
