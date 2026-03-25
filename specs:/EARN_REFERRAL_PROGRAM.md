# Earn — Referral Program

**Status:** Not started
**Priority:** P2 (soon — after persistence is wired)
**Estimated sessions:** 1 session
**Depends on:** Supabase auth working (done), SettingsView exists (done)

---

## What & Why

Riffit's referral program lets any user share a unique link. When someone signs up through that link and subscribes to a paid plan, the referrer earns commissions up to 3 levels deep. This is a growth engine — creators talk to other creators, and word-of-mouth is the #1 acquisition channel for tools like this. The UI needs to make sharing dead simple and show earnings clearly enough to motivate sharing.

---

## User Stories

- As a Riffit user, I want to copy my referral link so I can share it with other creators.
- As a Riffit user, I want to see how many people I've referred and how much I've earned so I stay motivated to share.
- As a Riffit user, I want to understand the commission structure so I know what I'll earn.

---

## Screens & Layout

### Settings — Earn Row
**File:** `Features/Settings/SettingsView.swift` (modify existing)
**Navigation:** Visible in Settings between Creative and App sections

**Row layout:**
- Left icon: 32×32, gold tint fill, dollar sign or gift icon (SF Symbol `gift.fill`)
- Title: "Earn" — SF Pro 17pt semibold
- Subtitle: dynamic — "$0.00 earned" when no earnings, "$XX.XX earned" when active
- Right: chevron (standard NavigationLink)
- Entire row is NavigationLink to EarnView

---

### EarnView (detail screen)
**File:** `Features/Settings/EarnView.swift` (new)
**Navigation:** Settings → Earn row tap

**Layout (top to bottom):**

1. **Page title** — "Earn" in Georgia Bold Italic 26pt (matches other Settings detail pages)

2. **Referral link card** — Surface background, 20pt radius
   - Label: "Your referral link" — Caption, text secondary
   - Link display: truncated URL in mono/code style — `riffit.app/r/USERNAME`
   - Copy button: teal tint pill, "Copy link" with doc.on.doc icon
   - Share button: teal tint pill, "Share" with square.and.arrow.up icon
   - On copy: haptic feedback + button text changes to "Copied!" for 2 seconds
   - On share: opens ShareSheet with referral URL + pre-written message

3. **Stats grid** — 2×2 grid of stat cards, Surface background, 14pt radius each
   - "Referrals" — total signups from your link (number, gold text)
   - "Paying" — total who converted to paid (number, gold text)
   - "This month" — commission earned this month (dollar amount, gold text)
   - "All time" — total commission earned (dollar amount, gold text)
   - All values are $0 / 0 at launch — this is fine, the UI still looks good

4. **Commission tiers section** — Header: "How it works" in SF Pro 17pt semibold
   - 3 tier cards stacked vertically, Surface background, 14pt radius
   - **Level 1:** "Direct referral" — "50% first month, then 10% recurring"
     - Left accent: 3pt gold bar
   - **Level 2:** "Their referrals" — "3% recurring (starts month 2)"
     - Left accent: 3pt teal bar
   - **Level 3:** "3 levels deep" — "1% recurring (starts month 2)"
     - Left accent: 3pt teal-900 bar
   - Below tiers: caption text — "$100/mo cap per referred account · Lifetime commissions"

5. **Network section** — Header: "Your network" in SF Pro 17pt semibold
   - **Empty state:** Centered illustration area
     - Headline: "No referrals yet" — Georgia Bold Italic 16pt
     - Subtext: "Share your link. Earn when they subscribe." — Georgia Italic 13pt, text secondary
   - **With data (future):** List of referred users with tier indicator, status, earnings

**Empty state (whole page):** Never fully empty — referral link + commission tiers always show. Only the network section has an empty state.

**Loading state:** ProgressView() tinted gold while fetching stats (stats section only)

**Error state:** Inline error text below stats grid: "Couldn't load earnings. Pull to retry." — Caption, danger color

---

## Data Model

### New Models

```
ReferralStats (local struct, not persisted — fetched from Edge Function)
  - totalReferrals: Int
  - payingReferrals: Int
  - earningsThisMonth: Decimal
  - earningsAllTime: Decimal
```

### No new Supabase tables at launch
Referral tracking will be handled by RevenueCat + a future Edge Function. For now, the UI is built with placeholder/zero data. The referral link is constructed from the user's username or user ID.

---

## ViewModel

**File:** `Features/Settings/EarnViewModel.swift` (new)

### State
- `@Published var stats: ReferralStats = ReferralStats.empty`
- `@Published var isLoading: Bool = false`
- `@Published var error: String? = nil`
- `@Published var linkCopied: Bool = false`
- `var referralLink: String` — computed from user ID/username

### Actions
- `func fetchStats()` — Stubbed for now. Will call Edge Function when referral backend exists. Returns .empty immediately.
- `func copyLink()` — Copies referralLink to UIPasteboard, sets linkCopied = true, triggers haptic, resets after 2s.
- `func shareLink()` — Returns (String, String) tuple for ShareSheet (URL + pre-written share text).

---

## Edge Cases

- User has no username set → referral link uses user ID instead
- User is on Free tier → can still share link and see the page; commissions only accrue when referred user pays
- Stats fetch fails → show error inline, don't block the page (link + tiers still visible)
- User taps Copy rapidly → debounce, only one clipboard write + haptic per 2s

---

## Design Tokens

- Colors: `colors.primary` (gold stats), `colors.teal400` (copy/share buttons), `colors.teal600` (L2 tier accent), `colors.teal900` (L3 tier accent), `colors.surface` (cards), `colors.textPrimary`, `colors.textSecondary`, `colors.textTertiary`
- Typography: Georgia Bold Italic 26pt (page title), SF Pro 17pt semibold (section headers), SF Pro 14pt (tier descriptions), Caption 12pt (fine print)
- Spacing: `.md` (16pt) card padding, `.sm` (8pt) between grid items, `.lg` (24pt) between sections
- Corner radius: 20pt for referral link card, 14pt for stat cards and tier cards
- Components: reuse `ShareSheet` (existing), `RiffitButton` teal variant for copy/share

---

## Acceptance Criteria

- [ ] EarnView.swift created with all 5 sections (link, stats, tiers, network)
- [ ] EarnViewModel.swift created with stubbed fetchStats, working copyLink, shareLink
- [ ] SettingsView.swift has new "Earn" row between Creative and App sections
- [ ] Referral link card: copy button writes to clipboard with haptic + "Copied!" feedback
- [ ] Referral link card: share button opens ShareSheet with link + share text
- [ ] Stats grid shows 4 cards with $0/0 values (gold text)
- [ ] Commission tiers show 3 levels with correct rates and colored left accents
- [ ] Network section shows empty state with Georgia Italic copy
- [ ] All colors use RiffitColors tokens (no hardcoded hex)
- [ ] All typography uses RiffitTheme / Georgia custom font (no raw .font(.system(...)))
- [ ] No force unwraps anywhere
- [ ] Build: zero errors confirmed
- [ ] CHANGES.md updated
- [ ] CONTEXT.md updated

---

## Claude Code Prompt

```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read:
- specs/EARN_REFERRAL_PROGRAM.md
- Features/Settings/SettingsView.swift
- Components/RiffitButton.swift
- Components/ShareSheet.swift
- Core/Design/RiffitColors.swift
- Core/Design/RiffitTheme.swift

Task: Build the Earn (referral program) screen and wire it into Settings.

Architecture:
- EarnView is a new NavigationLink destination from SettingsView
- EarnViewModel owns all state, stubbed data fetching (returns zeros)
- Referral link uses AppState.currentUser?.id or username
- Copy to clipboard via UIPasteboard.general
- Share via existing ShareSheet component
- No new Supabase tables — UI only with placeholder data

Design constraints:
- Never hardcode colors — always use RiffitColors tokens
- All fonts via RiffitTheme (RF/RS typealiases)
- All spacing from RiffitTheme.Spacing constants
- No force unwraps — use if let, guard let, or optional chaining
- No UIKit unless there is no SwiftUI equivalent
- Comments explaining WHY, not just what

Do not change anything outside SettingsView (adding row), EarnView, and EarnViewModel.
Build. Confirm zero errors.
Report: files created, files modified, zero build errors confirmed.
```

---

## Notes

- The referral backend (tracking clicks, attributing signups, calculating commissions) is a separate project. This spec is UI only.
- White-label referral tracking services (like Rewardful, FirstPromoter) could handle the backend. Decision deferred.
- The "Your network" section will eventually show a list of referred users — design that when the backend exists.
- Commission rates are locked (see CHANGES.md 2026-03-25 entry). Don't change without explicit approval.
