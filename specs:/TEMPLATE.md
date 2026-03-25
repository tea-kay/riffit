# Feature Spec Template

> Copy this file for each new feature. Delete this header block.
> Name the file: `FEATURE_NAME.md` (e.g., `EARN_REFERRAL_PROGRAM.md`)

---

# [Feature Name]

**Status:** Not started | In progress | Complete
**Priority:** P0 (blocking) | P1 (next up) | P2 (soon) | P3 (backlog)
**Estimated sessions:** [1-3 sessions, or "single prompt"]
**Depends on:** [other features or infrastructure that must exist first]

---

## What & Why

[2-3 sentences. What does this feature do? Why does it matter for the user or the business? What problem does it solve?]

---

## User Stories

- As a [user type], I want to [action] so that [outcome].
- As a [user type], I want to [action] so that [outcome].

---

## Screens & Layout

### [Screen Name]
**File:** `Features/[Area]/[FileName].swift`
**Navigation:** How user gets here (e.g., "Settings → Earn row tap")

**Layout (top to bottom):**
1. [Section] — [description, components, interactions]
2. [Section] — [description, components, interactions]
3. [Section] — [description, components, interactions]

**Empty state:** [what shows when there's no data]
**Loading state:** [what shows during fetch]
**Error state:** [what shows on failure]

---

## Data Model

### New Models
```
[ModelName]
  - field: Type — description
  - field: Type — description
```

### Modified Models
```
[ModelName] — add field: Type
```

### Supabase Tables (if applicable)
```sql
-- Table definition with RLS
```

---

## ViewModel

**File:** `Features/[Area]/[ViewModelName].swift`

### State
- `@Published var items: [Type] = []`
- `@Published var isLoading: Bool = false`

### Actions
- `func doThing()` — [what it does, what it calls]

---

## Edge Cases

- [What happens when X?]
- [What happens when Y?]
- [What if the user is on Free tier?]

---

## Design Tokens

- Colors: [which tokens from RiffitColors]
- Typography: [which font styles]
- Spacing: [any specific spacing notes]
- Components: [which existing components to reuse]

---

## Acceptance Criteria

- [ ] [Specific, testable requirement]
- [ ] [Specific, testable requirement]
- [ ] [Specific, testable requirement]
- [ ] Build: zero errors confirmed
- [ ] CHANGES.md updated
- [ ] CONTEXT.md updated

---

## Claude Code Prompt

> Paste this into Claude Code to build the feature.

```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read:
- specs/[THIS_SPEC].md
- [relevant existing files]

Task: [one sentence — what to build]

Architecture:
- [key decisions]

Design constraints:
- Never hardcode colors — always use RiffitColors tokens
- All fonts via RiffitTheme
- All spacing from RiffitTheme.Spacing constants
- No force unwraps
- No UIKit unless no SwiftUI equivalent

Do not change anything outside the scope of this task.
Build. Confirm zero errors.
Report: files created, files modified, zero build errors confirmed.
```

---

## Notes

[Anything else — future considerations, things explicitly excluded, open questions]
