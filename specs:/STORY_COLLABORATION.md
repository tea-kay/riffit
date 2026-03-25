# Story Collaboration

**Status:** Not started
**Priority:** P1 (next up — core feature, also a Pro upgrade gate)
**Estimated sessions:** 3-4 sessions
**Depends on:** Supabase auth (done), data persistence (P0, must be done first), Earn referral backend (partially — invite-as-referral needs referral tracking)

---

## What & Why

Creators don't work alone. An editor needs to see the story assets, leave feedback, and download footage. A co-creator needs to drop in references and notes. Story Collaboration lets the story owner invite people by link or username, assign them a role, and work together inside a shared story. This is also the #2 upgrade gate in the pricing spec — Free gets 1 collaborator, Pro gets 2, and it scales from there. Every invite is also a silent referral — if the collaborator doesn't have an account, signing up through the invite link credits the story owner as the referrer.

---

## User Stories

- As a creator, I want to invite my editor to a story so they can review assets and leave feedback.
- As a creator, I want to control what collaborators can do (view only vs. edit vs. full access).
- As a creator, I want to remove a collaborator if the project is done or they shouldn't have access anymore.
- As a collaborator, I want to join a story with minimal friction — no lengthy onboarding.
- As a collaborator, I want to leave notes and download assets so I can do my job.
- As a creator, I want inviting someone to automatically count as a referral if they're new to Riffit.

---

## Key Product Decisions

### Collaborators must have a Riffit account
A free account is sufficient. This gives them an identity (name, avatar for notes), enables RLS in Supabase, and creates a path to conversion. The pricing spec already states: "Clients can add collaborators from their side (free account required)."

### No onboarding for collaborators joining via invite
Full onboarding (creator type selection, AI interview, social connections) is for creators building their own library. A collaborator joining someone else's story just needs to exist as a user. Flow: tap invite link → sign in with Apple → land directly in the shared story. They can complete onboarding later if they want to use Riffit for their own content.

### Every invite is a silent referral
If the invited person doesn't already have a Riffit account, signing up through the invite link automatically credits the story owner as the referrer. The invite link carries the owner's user ID as the referral source. This means every collaboration is a potential Earn commission — editor signs up free, later upgrades to Pro for their own work, and the original creator earns 50% of month 1 + 10% recurring. No separate referral link needed.

### Role model: simple for Free/Pro, granular for Studio+

**Free & Pro tiers** (no `role_permissions` entitlement):
- **Owner** — full control (implicit, the story creator)
- **Collaborator** — can view all assets, leave notes, download assets. Cannot add/edit/delete assets, sections, or references. Cannot invite others.

**Studio, Agency, Agency Pro** (`role_permissions: true`):
- **Owner** — full control, can invite/remove anyone, transfer ownership
- **Editor** — can add/edit/delete assets, sections, references, and notes. Cannot invite/remove people or delete the story.
- **Viewer** — can view all assets and notes, download assets. Cannot modify anything. Cannot leave notes.
- **Commenter** — can view all assets and leave notes. Cannot modify assets. Cannot download. (This is the "client review" role for Agency tiers.)

### Collaborator limits are enforced server-side
The `collaborators_per_story` entitlement (1/2/4/10/10 by tier) is checked when adding a collaborator. The owner's tier determines the cap, not the collaborator's tier. Client-side shows the limit in UI but never trusts it for enforcement.

### Shared stories live in the collaborator's Storybank, not a separate space
A collaborator does not get access to the owner's Library, other stories, or settings. Shared stories appear in the collaborator's own Storybank in a "Shared with me" section below their own stories and above folders. This section only appears if the user has at least one shared story (accepted or pending) — solo creators who never collaborate never see it. The Storybank is the creator's workspace, and someone else's story is clearly attributed ("by Sarah") so it's never confused with their own work. Shared stories are not a folder — they're real stories that happen to belong to someone else, surfaced inline with clear ownership attribution.

---

## Invite Flow

### Owner sends invite

1. Owner opens StoryDetailView → taps "People" in toolbar (or a collaborators section)
2. **Invite sheet** appears with two options:
   - **Copy invite link** — generates `riffit.app/invite/{story_id}?ref={owner_user_id}`
   - **Invite by username** — search field, finds existing Riffit users, sends in-app invite
3. If the owner's tier has `role_permissions`, they also pick a role (Editor / Viewer / Commenter) before sending. Otherwise, role defaults to "Collaborator."
4. Server checks `collaborators_per_story` limit before creating the invitation. If at limit → paywall prompt.

### New user receives invite link

1. Taps link → opens Riffit (or App Store if not installed)
2. Deep link carries `story_id` + `ref` (referral source)
3. If not signed in → **CollabJoinView** appears:
   - Story title + owner name/avatar displayed ("Sarah invited you to *Summer Campaign*")
   - "Join with Apple" button (Apple Sign In — one tap)
   - Small print: "Free account. No credit card."
4. Apple Sign In → auto-creates user row (existing `handle_new_user` trigger) → stores `ref` as `referred_by` on user record
5. Skips onboarding entirely → creates `StoryCollaborator` record → navigates directly to the shared StoryDetailView
6. The story appears in their Storybank under "Shared with me"

### Existing user receives invite link

1. Taps link → opens Riffit
2. If already signed in → **CollabJoinView** shows story preview + "Join" button
3. Taps Join → creates `StoryCollaborator` record → navigates to the shared story
4. No referral credit (they already have an account)

### Existing user receives in-app invite

1. Gets a notification badge on their Storybank tab (or a banner)
2. "Shared with me" section shows the pending invite with Accept / Decline
3. Accept → creates `StoryCollaborator` record → story becomes accessible
4. Decline → deletes the invitation record

---

## Screens & Layout

### StoryDetailView — Collaborators Section (modify existing)
**File:** `Features/Storybank/StoryDetailView.swift`

Add a **PEOPLE** section between NOTES and the toolbar, showing:
- Row per collaborator: avatar (32×32) + display name + role pill + "..." menu
- Role pill: teal tint for Editor, surface for Viewer, primary tint for Owner
- "..." menu: Change role (Studio+ only), Remove from story
- Owner row is always first, no "..." menu, "Owner" pill in gold
- "+ Invite" row at the bottom of the people list → opens invite sheet
- If at collaborator limit: "+ Invite" row shows lock icon + "Upgrade to add more"

### InviteSheet (new)
**File:** `Features/Storybank/InviteSheet.swift`

Bottom sheet with:
1. **Invite link section** — "Share invite link" header
   - Generated link display (truncated, mono style)
   - Copy button (teal pill) + Share button (teal pill)
   - Copy triggers haptic + "Copied!" feedback (same pattern as EarnView)
2. **Invite by username section** — "Find on Riffit" header
   - Search field → debounced Supabase query on `users.username`
   - Results list: avatar + display name + username
   - Tap result → shows role picker (if Studio+) → sends invite
3. **Role picker** (Studio+ only, hidden on Free/Pro)
   - Segmented control or pill row: Editor · Viewer · Commenter
   - Default: Editor

### CollabJoinView (new)
**File:** `Features/Storybank/CollabJoinView.swift`

Full-screen view shown when opening an invite link:
- Owner avatar (64×64) + display name
- Story title in Georgia Bold Italic
- "invited you to collaborate" — subtext, Georgia Italic, text secondary
- Asset count preview: "12 assets · 3 references" — caption
- "Join" primary button (gold, full width) — if signed in
- "Join with Apple" button (Apple Sign In style) — if not signed in
- "No thanks" text button below — dismisses

### StorybankView — "Shared with me" Section (modify existing)
**File:** `Features/Storybank/StorybankView.swift`

**Position:** Below the user's own stories, above folders. The section only renders if the user has at least one shared story (accepted or pending). If zero shared stories exist, the section is completely absent — no empty state, no header, nothing. Solo creators never see it.

**Section header:** "Shared with me" — Label style (SF Pro 11pt, 500 weight, uppercase, tracking 0.06em), text secondary. Same treatment as other Storybank section headers.

**Accepted story rows:**
- StoryCard layout but with owner attribution added:
  - Owner avatar (24×24 circle) + "by [display name]" — Caption, text tertiary, below the story title
  - Role pill trailing the owner name: "Editor" (teal tint), "Viewer" (surface), "Commenter" (surface), "Collaborator" (teal tint)
  - Unread indicator: small gold dot (6pt) on the leading edge of the row if there are new notes since the collaborator's last visit. Tracked via `last_viewed_at` on the `story_collaborators` record.
  - Tap → navigates to StoryDetailView (permission-gated based on role)
  - Long press → context menu: "Leave story" (with confirmation)

**Pending invite rows:**
- Same card shape but muted (opacity 0.8 on content)
- Owner avatar + "Sarah invited you to *Summer Campaign*" — Georgia Italic, text secondary
- Two buttons inline: "Accept" (teal tint pill) + "Decline" (surface pill, text secondary)
- Accept → creates `StoryCollaborator` record with `status: accepted`, row animates into normal accepted state
- Decline → deletes invitation record, row animates out

**Sort order:** Pending invites first (newest on top), then accepted stories sorted by most recently updated.

**Mental model:** This is not a folder. It's a section of the Storybank — the collaborator's creative workspace includes both their own stories and stories shared with them. The attribution (avatar + "by [name]") is what distinguishes them. The owner's identity is always visible so the collaborator never confuses someone else's project with their own.

### ManageCollaboratorsView (new, for owner)
**File:** `Features/Storybank/ManageCollaboratorsView.swift`

Accessible from StoryDetailView toolbar → "Manage people"
- Full list of collaborators with roles
- Swipe-to-remove or tap "..." → Remove
- Change role (Studio+ only): tap role pill → picker
- Invite count: "2 of 4 collaborators" (shows tier limit)
- "Upgrade for more" link if at limit → paywall

---

## Data Model

### New: StoryCollaborator (Supabase table + Swift model)
```sql
CREATE TABLE story_collaborators (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    user_id         uuid REFERENCES users(id) ON DELETE CASCADE,
    role            text CHECK (role IN ('owner', 'editor', 'viewer', 'commenter', 'collaborator')) DEFAULT 'collaborator',
    invited_by      uuid REFERENCES users(id),
    status          text CHECK (status IN ('pending', 'accepted', 'declined')) DEFAULT 'pending',
    created_at      timestamptz DEFAULT now(),
    accepted_at     timestamptz,
    last_viewed_at  timestamptz,              -- tracks when collaborator last opened the story, for unread dot
    UNIQUE(story_id, user_id)
);

ALTER TABLE story_collaborators ENABLE ROW LEVEL SECURITY;

-- Owners can manage all collaborators on their stories
CREATE POLICY "owners can manage collaborators" ON story_collaborators
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM stories
            WHERE stories.id = story_collaborators.story_id
            AND stories.creator_profile_id IN (
                SELECT id FROM creator_profiles WHERE user_id = auth.uid()
            )
        )
    );

-- Collaborators can read their own records and other collaborators on shared stories
CREATE POLICY "collaborators can view shared story members" ON story_collaborators
    FOR SELECT USING (
        user_id = auth.uid()
        OR story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

-- Users can accept/decline their own invitations
CREATE POLICY "users can respond to invitations" ON story_collaborators
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
```

```swift
// Swift model
struct StoryCollaborator: Identifiable, Codable {
    let id: UUID
    let storyId: UUID
    let userId: UUID
    var role: CollaboratorRole
    let invitedBy: UUID?
    var status: CollaboratorStatus
    let createdAt: Date
    var acceptedAt: Date?
    var lastViewedAt: Date?          // when collaborator last opened the story — drives unread dot
}

enum CollaboratorRole: String, Codable, CaseIterable {
    case owner
    case editor
    case viewer
    case commenter
    case collaborator  // simplified role for Free/Pro tiers
}

enum CollaboratorStatus: String, Codable {
    case pending
    case accepted
    case declined
}
```

### New: StoryInviteLink (Supabase table)
```sql
CREATE TABLE story_invite_links (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    created_by      uuid REFERENCES users(id),
    role            text CHECK (role IN ('editor', 'viewer', 'commenter', 'collaborator')) DEFAULT 'collaborator',
    referral_user_id uuid REFERENCES users(id),  -- owner's user_id for referral attribution
    token           text UNIQUE NOT NULL,         -- short random token for the URL
    expires_at      timestamptz,                  -- nullable = never expires
    max_uses        int,                          -- nullable = unlimited
    use_count       int DEFAULT 0,
    created_at      timestamptz DEFAULT now()
);

ALTER TABLE story_invite_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owners can manage invite links" ON story_invite_links
    FOR ALL USING (created_by = auth.uid());
```

### Modified: users table
```sql
-- Add referral tracking column
ALTER TABLE users ADD COLUMN referred_by uuid REFERENCES users(id);
```

### Modified: StoryNote
Notes already have `authorName` but need `userId` for permission checks:
```sql
ALTER TABLE story_notes ADD COLUMN user_id uuid REFERENCES users(id);
```

### Modified: RLS on story_assets, story_references, story_notes
Current RLS only allows the story owner. Needs to also allow accepted collaborators with appropriate roles:
```sql
-- Example pattern for story_assets (similar for references, notes)
CREATE POLICY "collaborators can read shared story assets" ON story_assets
    FOR SELECT USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY "editors can modify shared story assets" ON story_assets
    FOR INSERT USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );
```

---

## Permission Matrix

| Action | Owner | Editor | Viewer | Commenter | Collaborator (Free/Pro) |
|---|---|---|---|---|---|
| View assets | ✅ | ✅ | ✅ | ✅ | ✅ |
| Download/export assets | ✅ | ✅ | ✅ | ❌ | ✅ |
| Add/edit/delete assets | ✅ | ✅ | ❌ | ❌ | ❌ |
| Add/edit sections | ✅ | ✅ | ❌ | ❌ | ❌ |
| Add/edit references | ✅ | ✅ | ❌ | ❌ | ❌ |
| Leave notes | ✅ | ✅ | ❌ | ✅ | ✅ |
| Edit own notes | ✅ | ✅ | ❌ | ✅ | ✅ |
| Delete others' notes | ✅ | ❌ | ❌ | ❌ | ❌ |
| Invite collaborators | ✅ | ❌ | ❌ | ❌ | ❌ |
| Remove collaborators | ✅ | ❌ | ❌ | ❌ | ❌ |
| Change roles | ✅ | ❌ | ❌ | ❌ | ❌ |
| Rename story | ✅ | ✅ | ❌ | ❌ | ❌ |
| Delete story | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duplicate story | ✅ | ✅ | ❌ | ❌ | ❌ |

**The "Collaborator" role (Free/Pro)** is intentionally between Viewer and Editor — they can view, download, and comment, but cannot modify the creative work. This is the editor/client use case: "Look at my stuff, give me feedback, grab what you need."

---

## Referral Integration

### How invite links carry referral attribution

The invite link format: `riffit.app/invite/{token}`

The `story_invite_links` table stores `referral_user_id` (always the story owner's user_id).

When a new user signs up through this link:
1. The deep link handler reads the token → fetches the invite link record → gets `referral_user_id`
2. The new user's `users.referred_by` is set to the owner's user_id
3. Standard Earn referral logic kicks in from there (tracked by RevenueCat webhook when they subscribe)

When an existing user taps the link:
- No referral credit (they already have an account)
- They just join the story normally

### Edge case: user already referred by someone else
First referrer wins. If `referred_by` is already set on the user record, it's not overwritten. The collab invite still works — they just join the story without changing referral attribution.

---

## Edge Cases

- **Owner deletes story** → all `story_collaborators` cascade delete, story disappears from everyone's "Shared with me" section immediately
- **Collaborator leaves voluntarily** → they can tap "Leave story" from long-press context menu in "Shared with me" or from the people section inside the story → deletes their `story_collaborators` record → row animates out of Storybank
- **Owner downgrades tier** → existing collaborators stay, but new invites are blocked if over the new tier's limit. No one gets kicked automatically.
- **Invite link shared publicly** → `max_uses` and `expires_at` provide guardrails. Owner can also revoke the link (delete the record).
- **Same person invited twice** → UNIQUE(story_id, user_id) constraint prevents duplicates. If pending, re-invite updates the role. If already accepted, no-op.
- **Collaborator has no profile photo** → falls back to initials circle (existing pattern)
- **Offline** → collaborators list and role checks are cached client-side for UI, but all mutations require network. Notes left offline queue for sync (future).
- **User has zero shared stories** → "Shared with me" section does not render at all. No empty state, no header. Section appears the moment the first invite arrives or story is shared.
- **All shared stories removed/left** → "Shared with me" section disappears again. Clean Storybank.
- **Unread dot persistence** → `last_viewed_at` updated every time collaborator opens the shared StoryDetailView. Unread dot shows if any `story_notes.created_at` > `last_viewed_at`.

---

## Upgrade Gates (Paywall Moments)

This feature creates two natural paywall touchpoints:

1. **Free user tries to add a 2nd collaborator** → "Upgrade to Pro to invite up to 2 collaborators per story"
2. **Pro user wants Editor/Viewer/Commenter roles** → "Upgrade to Studio for role permissions" (Pro only gets the simplified "Collaborator" role)

These are high-intent moments — the user is actively trying to work with someone and hits the wall exactly when motivation is highest.

---

## Design Tokens

- Colors: `colors.primary` (owner pill), `colors.teal400` (editor pill, invite buttons), `colors.surface` (viewer/commenter pills), `colors.textPrimary`, `colors.textSecondary`
- Typography: Georgia Bold Italic (story title in CollabJoinView), SF Pro (everything else)
- Spacing: `.md` for section padding, `.sm` for avatar-to-name gap, `.lg` between sections
- Corner radius: 20pt for cards, 14pt for rows, full capsule for role pills
- Components: reuse `ShareSheet`, `RiffitButton` (primary + teal), role pills follow tag pill pattern

---

## Session Breakdown for Building

### Session 1: Data layer + models
- Create `StoryCollaborator` model + `CollaboratorRole` + `CollaboratorStatus` enums
- Create `StoryInviteLink` model
- SQL migration: `story_collaborators` table, `story_invite_links` table, `users.referred_by` column, `story_notes.user_id` column
- Updated RLS policies on `story_assets`, `story_references`, `story_notes`
- Edge Function: `create-invite-link`, `accept-invite`, `remove-collaborator`

### Session 2: Owner-side UI
- People section in StoryDetailView
- InviteSheet (link + username search + role picker)
- ManageCollaboratorsView
- Collaborator limit enforcement (UI-side check + server-side enforcement)
- Paywall prompt when at limit

### Session 3: Collaborator-side UI
- CollabJoinView (deep link landing)
- "Shared with me" section in StorybankView (conditional rendering, sort order, pending vs accepted states)
- Shared story card rows with owner avatar, attribution, role pill, unread gold dot
- Pending invite accept/decline flow with animations
- `last_viewed_at` tracking for unread indicator
- Permission-aware StoryDetailView (hide/disable actions based on role)
- "Leave story" action from long-press context menu and people section

### Session 4: Deep linking + referral wiring
- Universal link handling for `riffit.app/invite/{token}`
- App Store redirect if not installed (deferred deep link)
- Referral attribution on new account creation
- In-app invite notification (badge or banner)

---

## Acceptance Criteria

- [ ] `story_collaborators` table created with RLS
- [ ] `story_invite_links` table created with RLS
- [ ] `users.referred_by` column added
- [ ] StoryCollaborator Swift model + enums created
- [ ] People section visible in StoryDetailView showing all collaborators with roles
- [ ] Owner can generate and copy/share an invite link
- [ ] Owner can search by username and send in-app invite
- [ ] Owner can remove a collaborator with confirmation
- [ ] Studio+ owner can assign Editor/Viewer/Commenter roles
- [ ] Free/Pro owner can only assign the simplified "Collaborator" role
- [ ] CollabJoinView shows story preview + one-tap join (or Apple Sign In for new users)
- [ ] New user signing up via invite link gets `referred_by` set to story owner
- [ ] Accepted collaborators see the story in "Shared with me" section in their Storybank
- [ ] "Shared with me" section only appears when user has ≥1 shared/pending story
- [ ] "Shared with me" section disappears when all shared stories are removed/left
- [ ] Shared story rows show owner avatar + "by [name]" + role pill
- [ ] Gold unread dot appears on shared story row when new notes exist since last visit
- [ ] `last_viewed_at` updates when collaborator opens a shared story
- [ ] Pending invites show inline with Accept/Decline buttons
- [ ] Accept animates row into normal state; Decline animates row out
- [ ] Long-press on shared story row shows "Leave story" with confirmation
- [ ] Pending invites sorted first, then accepted stories by most recently updated
- [ ] Permission matrix enforced: collaborators cannot perform actions outside their role
- [ ] Collaborator limit enforced per owner's tier (server-side)
- [ ] Paywall shown when owner hits collaborator limit
- [ ] Owner downgrade: existing collabs preserved, new invites blocked if over limit
- [ ] All colors use RiffitColors tokens
- [ ] All typography uses RiffitTheme / Georgia custom font
- [ ] No force unwraps
- [ ] Build: zero errors confirmed
- [ ] CHANGES.md updated
- [ ] CONTEXT.md updated

---

## Notes

- **Push notifications for invites** are a future enhancement. V1 uses in-app "Shared with me" section with pending state.
- **Real-time collaboration** (seeing each other's cursors, live note updates) is out of scope. This is async collaboration — you leave notes, they read them next time they open the story.
- **Ownership transfer** is deferred. V1 only supports the creator as permanent owner.
- **Collaborator analytics** (who viewed what, when) is deferred. V1 is just access + notes.
- **The "Collaborator" role for Free/Pro** is a deliberate product choice — it's generous enough to be useful (view + download + notes) but limited enough that teams who need real editing workflows upgrade to Studio.
