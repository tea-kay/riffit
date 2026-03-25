# Riffit — Changelog

> Append-only log of every session. Newest entries at the bottom.
> Each entry follows the template in CLAUDE.md (Session Startup section).

---

### 2026-03-15 — AI removal, model simplification, card title logic

**What changed:**
- Removed all AI-related UI (shimmer, alignment badges, scores, pending states)
- Simplified InspirationVideo.Status to saved/archived
- Added title field to model and capture sheet
- New card title hierarchy: title → first 8 words of note → platform + "reel"
- Removed video stats (viewCount, likeCount, commentCount) from entire app
- Fixed reference cards showing "Linked inspiration" → now shows real video title
- Fixed InspirationCard losing full width after stats removal
- Added fetchVideos() call to AddReferenceView.onAppear

**Files modified:**
- InspirationVideo.swift, InspirationCard.swift, LibraryViewModel.swift
- AddInspirationView.swift, InspirationDetailView.swift, StoryDetailView.swift
- AddReferenceView.swift, EdgeFunctions.swift

**Build status:** Zero errors confirmed

### 2026-03-16 — Asset sections, references rework, tags, folders, media

**What changed:**
- Asset sections with flat list drag reorder across sections
- References now use story sections instead of hardcoded 6-tag picker
- Interactive tags (toggle, create custom, delete any including defaults)
- Storybank folders (create, rename, delete, drag-to-organize)
- Voice note recording (press-and-hold, preview with editable title)
- Image attachments (camera + library, preview with editable title)
- Thumbnails in asset rows for images
- Editable idea titles in detail view
- Folder browsing in AddReferenceView picker
- Folder picker in capture sheet (Menu with full-width row)

**Files created:**
- AssetSection.swift, StoryFolder.swift, FlowLayout.swift
- AudioRecorderService.swift, AudioPlayerService.swift
- ImageStorageService.swift, CameraPickerView.swift
- VoiceNoteRecordSheet.swift, VoiceNotePlayerView.swift
- ImageAttachmentSheet.swift, ImageViewerView.swift

**Build status:** Zero errors confirmed

### 2026-03-17 — Video attachments, export, notes, Settings restructure

**What changed:**
- Video attachments (record + library, preview with AVPlayer, editable title)
- Video thumbnails in asset rows
- Asset export (single via long-press, all via toolbar menu, Camera Roll + share)
- Editable notes in InspirationDetailView (inline tap-to-edit)
- Notes section added to StoryDetailView (with timestamps)
- SettingsView full restructure (Account/Plan/Creative/App/Legal/Sign out)
- AccountView built (profile photo, editable name/username, workspace placeholders)

**Files created:**
- VideoStorageService.swift, VideoPickerView.swift
- VideoAttachmentSheet.swift, VideoPlayerView.swift
- AssetExportService.swift, ShareSheet.swift
- StoryNote.swift, AccountView.swift

**Build status:** Zero errors confirmed

### 2026-03-18 — InfluencesView, avatar on notes, context consolidation

**What changed:**
- InfluencesView built (analytics from references: most referenced, tag breakdown, pattern card)
- StorybankViewModel lifted to MainTabView as shared @EnvironmentObject
- Avatar + display name added to CommentBubble (InspirationDetailView)
- Avatar + display name added to StoryNoteBubble (StoryDetailView)
- addComment/addNote now accept authorName parameter
- Profile photo picker changed to direct PhotosPicker (no intermediate dialog)
- SettingsView wired to InfluencesView with dynamic subtitle
- Context files reorganized: CONTEXT.md (current state) + CHANGES.md (this file)

**Files created:**
- InfluencesView.swift, CONTEXT.md, CHANGES.md

**Files modified:**
- MainTabView.swift, StorybankView.swift, SettingsView.swift
- InspirationDetailView.swift, StoryDetailView.swift
- LibraryViewModel.swift, StorybankViewModel.swift, AccountView.swift
- CLAUDE.md

**Build status:** Zero errors confirmed

### 2026-03-18 — Settings avatar, display name, empty state copy, progress report

**What changed:**
- Settings account card now shows profile photo + display name from @AppStorage (was hardcoded)
- Display name logic: @username if set, else full name — applied to SettingsView + AccountView
- "New account" row removed from AccountView workspace section
- Empty state copy: "Catch a reel. Drop it here." → "Catch your first idea.", "Drop your first reel" → "Drop your first find"
- Deleted AlignmentBadge.swift (unused since AI removal) + removed from pbxproj
- Generated RIFFIT_PROGRESS_REPORT.md — full project audit
- Session startup prompt templates added to CLAUDE.md
- Documentation restructured: CONTEXT.md (overwrite) + CHANGES.md (append)

**Files created:**
- RIFFIT_PROGRESS_REPORT.md, CHANGES.md, CONTEXT.md

**Files modified:**
- SettingsView.swift, AccountView.swift, LibraryView.swift, CLAUDE.md

**Files deleted:**
- AlignmentBadge.swift

**Build status:** Zero errors confirmed

### 2026-03-19 — Platform support, idea deletion, story toolbar, cards, search

**What changed:**
- YouTube support: URL validation, platform auto-detection, thumbnail + deep link (no WKWebView — Error 153 fix)
- TikTok support: embed URL extraction, 9:16 vertical aspect ratio display
- X/Twitter support: thumbnail or placeholder card, deep link to X app with Safari fallback
- PlatformDetector helper: detect, youtubeVideoId, tiktokVideoId, xStatusId, openXPost, icon, urlPlaceholder
- Multi-platform URL validation in CaptureSheet (was Instagram-only)
- Platform icon + label update dynamically as URL is pasted
- Idea title persistence fix: Equatable on InspirationVideo now compares id + title + status (was id-only, prevented SwiftUI re-render)
- Idea deletion: long-press on card in LibraryView + toolbar menu in InspirationDetailView, with confirmation alert
- Orphaned reference cleanup: StorybankViewModel.removeReferences(for:) strips references across all stories when an idea is deleted
- LibraryViewModel.deleteVideo removes video + folder mapping + tags + comments
- Reference cards in StoryDetailView: added platform dot + name, "Your take" note row
- StoryDetail toolbar: reordered menu, added Share (ShareSheet) and Duplicate (full deep copy)
- Compose menu item: sparkles icon, greyed out, disabled (v2 AI placeholder)
- Story duplication: copies story + assets + references + sections + notes with new IDs
- Author avatar on StoryCard: 28×28 circle from @AppStorage, trailing the timestamp row
- Tag filtering on Library main page: search bar + horizontal tag filter pills
- Tag filtering on AddReferenceView picker: same search + tag filter bar

**Decisions made:**
- YouTube/X use thumbnail + deep link, not WKWebView (both block embeds)
- TikTok uses embed URL in WKWebView (works)
- InspirationVideo Equatable must include mutable fields for SwiftUI diffing
- Platform detection logic lives in PlatformDetector helper, never in View body

**Files created:**
- PlatformDetector.swift

**Files modified:**
- LibraryView.swift, LibraryViewModel.swift, InspirationDetailView.swift
- AddInspirationView.swift, AddReferenceView.swift
- StoryDetailView.swift, StorybankViewModel.swift, StorybankView.swift, AccountView.swift

**Build status:** Zero errors confirmed

### 2026-03-24 — Supabase project setup, schema, Apple Sign In auth

**What changed:**
- Supabase project created and connected to iOS app
- Full schema SQL run: 7 tables (users, creator_profiles, inspiration_videos, inspiration_folders, stories, story_assets, story_references) with RLS enabled on all
- Auto-create user trigger: `handle_new_user()` fires on `auth.users` insert, creates `public.users` row
- Supabase Swift SDK added via SPM (`https://github.com/supabase/supabase-swift`)
- `SupabaseClient.swift` singleton wired with URL + anon key from `Config.xcconfig`
- `Config.xcconfig` created for Supabase keys (added to `.gitignore`)
- Apple Sign In capability added to Xcode project
- `AuthViewModel` handles `ASAuthorization` → extracts `identityToken` → calls `supabase.auth.signInWithIdToken(credentials: .apple(idToken:, nonce:))`
- `AppState` listens to `supabase.auth.authStateChanges` async stream, sets `currentUser` on session, nils on sign out
- `RiffitApp.swift` routes between AuthView and MainTabView based on `AppState.currentUser`
- Session persists to Keychain — app skips auth on relaunch if session exists
- Sign out button in SettingsView wired to `AppState.signOut()` → `supabase.auth.signOut()`
- SettingsView profile card wired to real Supabase user data (email, full_name, avatar_url, subscription_tier) via `@EnvironmentObject AppState`
- Display name: `full_name` if set, else email prefix, prefixed with `@`
- Avatar: `AsyncImage` from `avatar_url`, falls back to initials on teal circle
- Removed hardcoded user data from Settings ("@TK", "Creator", "Free plan")
- Debug test user bypass in AuthView (`#if DEBUG` only)

**Decisions made:**
- Supabase keys live in Config.xcconfig (gitignored), not hardcoded in Swift
- Auth uses ASAuthorization → signInWithIdToken (not Supabase's built-in OAuth redirect)
- AppState owns auth state via authStateChanges async stream
- Settings pulls user data from AppState.currentUser, no separate network calls
- Dev Supabase project uses personal Gmail; prod will use dedicated email

**Files created:**
- Config.xcconfig

**Files modified:**
- SupabaseClient.swift, AppState.swift, RiffitApp.swift
- AuthView.swift, AuthViewModel.swift, SettingsView.swift
- .gitignore

**Build status:** Zero errors confirmed

### 2026-03-25 — UI polish: card layout, empty state alignment, ghost buttons

**What changed:**
- InspirationCard: timestamp moved from footer to top-right, aligned with platform row
- InspirationCard: sort confirmed newest-first
- InspirationCard: avatar stays trailing in footer row
- Library and Storybank empty states: aligned to identical vertical positions (illustration, headline, subtext, button all at same Y when switching tabs)
- New `RiffitGhostButtonStyle` created: black fill, gold text, gold border; inverts to gold fill, black text on press with .easeInOut 0.15s
- Ghost button style applied to both Library and Storybank empty state CTA buttons
- Ghost button added to RiffitButton.swift as reusable app-wide component

**Files created:**
- None (RiffitGhostButtonStyle added inside existing RiffitButton.swift)

**Files modified:**
- InspirationCard.swift, LibraryView.swift, StorybankView.swift, RiffitButton.swift

**Build status:** Zero errors confirmed

### 2026-03-25 — Referral program ("Earn") — spec only, not yet built

**What was specced:**
- 3-level deep referral commission system designed and locked
- Commission rates: L1 50% first month + 10% recurring, L2 3% recurring (starts month 2), L3 1% recurring (starts month 2)
- $100/mo cap per referred account at all levels
- Lifetime commissions as long as referred user stays subscribed
- Everyone can share a referral link; commissions only on paid subscriptions
- Settings UI: new "Earn" section between Creative and App sections
- EarnView detail screen: referral link + copy, stats grid, commission tiers visual, network empty state

**Files to create (next session):**
- Features/Settings/EarnView.swift
- Features/Settings/EarnViewModel.swift

**Files to modify (next session):**
- Features/Settings/SettingsView.swift (add Earn section row)

**Build status:** Spec only — no code changes this entry

### 2026-03-25 — Story Collaboration (full feature, 4 sessions, in-memory)

**What changed:**

*Session 1 — Data layer:*
- `StoryCollaborator` model with `CollaboratorRole` (owner/editor/viewer/commenter/collaborator) and `CollaboratorStatus` (pending/accepted/declined) enums
- `StoryInviteLink` model with token, expiry, max_uses, use_count, referral_user_id, `isActive` computed property
- CollaboratorRole has full permission matrix as computed properties: canViewAssets, canModifyAssets, canLeaveNotes, canDownloadAssets, canInviteCollaborators, canDeleteStory, etc.
- SQL migration `Migrations/003_story_collaboration.sql` (not run — for manual review): story_collaborators table, story_invite_links table, users.referred_by column, story_notes.user_id column, RLS policies for collaborator access on story_assets/story_references/story_notes
- `StoryNote` updated with `userId: UUID?` field + CodingKeys for Supabase mapping
- `RiffitUser` updated with `referredBy: UUID?` field

*Session 2 — Owner-side UI:*
- PEOPLE section in StoryDetailView between Notes and List end: CollaboratorRow per member, role pills (gold for Owner, teal for Editor/Collaborator, surface for Viewer/Commenter)
- `InviteSheet.swift` — bottom sheet with invite link (copy + haptic + "Copied!" feedback + ShareSheet), username search with debounced query, role picker (hidden for Free/Pro, visible for Studio+)
- `ManageCollaboratorsView.swift` — full-screen collaborator management, swipe-to-remove, collaborator count display ("2 of 4"), upgrade prompt at limit
- `CollaboratorRow` component reused in both People section and ManageCollaboratorsView
- Invite row at bottom of People section with lock icon when at collaborator limit
- "Manage People" added to StoryDetailView toolbar menu
- StorybankViewModel: addCollaborator, removeCollaborator, updateCollaboratorRole, ensureOwnerCollaborator, fetchCollaborators (stubbed)

*Session 3 — Collaborator-side UI:*
- "Shared with me" section in StorybankView: only renders if ≥1 shared/pending story, completely absent otherwise
- `SharedStoryCard` — owner avatar (24×24) + "by [name]" attribution + role pill + gold unread dot (6pt)
- `PendingInviteRow` — muted card (opacity 0.8) with Accept (teal pill) / Decline (surface pill), animated transitions
- `CollabJoinView.swift` — full-screen invite landing: owner avatar (64×64), story title, "invited you to collaborate", asset count preview, Join/Join with Apple button, "No thanks" dismiss
- Permission-gated StoryDetailView: all UI elements conditionally shown/hidden based on CollaboratorRole computed properties
- "Leave Story" in toolbar menu for non-owners (replaces Delete Story)
- Unread tracking: lastViewedAt updated on story open, hasUnreadNotes() compares note timestamps
- StorybankViewModel: sharedCollaborations, pendingInvites, acceptedSharedStories, acceptInvite, declineInvite, leaveStory, updateLastViewed, hasUnreadNotes, currentUserRole, fetchSharedStories (stubbed)

*Session 4 — Deep linking + referral wiring:*
- `.onOpenURL` on RiffitApp root WindowGroup — handles `riffit.app/invite/{token}` URLs
- AppState deep link state: pendingInviteToken, pendingReferralUserId, resolvedInvite, showCollabJoinView, inviteError
- `handleDeepLink(_:)` parses URL path + query params, stores token, shows CollabJoinView if signed in
- `clearPendingInvite()` cleans up all invite state after join/dismiss
- `checkPendingInviteAfterAuth()` re-shows CollabJoinView after auth completes
- CollabJoinView rewritten to be state-driven: reads from AppState, three states (loading/resolved/error)
- Error states: expired, not found, already member — each with icon, message, and dismiss button
- StorybankViewModel: inviteLinks store (keyed by token), resolveInviteToken (validates isActive, checks duplicate membership, hydrates preview), joinStoryFromInvite (creates collaborator + increments use_count)
- AuthViewModel: reads pendingReferralUserId from AppState, passes as referred_by on new user creation, calls checkPendingInviteAfterAuth after auth completes
- RootView: CollabJoinView as ZStack overlay above main content, animated with .easeInOut

**Decisions made:**
- All collaboration data is in-memory — same pattern as Library/Storybank. Persistence is the next P0.
- Permission checks use CollaboratorRole computed properties (canModifyAssets, canLeaveNotes, etc.) — never duplicated in Views
- Deep link parsing lives in AppState.handleDeepLink, invite resolution in StorybankViewModel
- pendingInviteToken survives auth flow — stored in AppState before sign-in, resolved after
- CollabJoinView is a ZStack overlay on RootView, not a sheet — ensures it appears over both AuthView and MainTabView
- Referral attribution: first referrer wins (referred_by only set if nil on user record)
- SectionHeaderRow accepts showActions parameter to hide rename/delete for non-editors
- Collaborator limit is UI-side only for now (hardcoded per tier: Free=1, Pro=2)

**Files created:**
- Models/StoryCollaborator.swift
- Models/StoryInviteLink.swift
- Migrations/003_story_collaboration.sql
- Features/Storybank/InviteSheet.swift
- Features/Storybank/ManageCollaboratorsView.swift
- Features/Storybank/CollabJoinView.swift

**Files modified:**
- Models/StoryNote.swift (added userId, CodingKeys)
- Models/User.swift (added referredBy)
- Features/Storybank/StorybankViewModel.swift (collaborators, invite links, shared stories, permissions, unread tracking)
- Features/Storybank/StoryDetailView.swift (People section, permission gating, leave story, lastViewedAt)
- Features/Storybank/StorybankView.swift (Shared with me section, SharedStoryCard, PendingInviteRow)
- Features/Auth/AuthView.swift (referredBy on test user)
- Features/Auth/AuthViewModel.swift (referral attribution, checkPendingInviteAfterAuth)
- App/AppState.swift (deep link state, handleDeepLink, clearPendingInvite, checkPendingInviteAfterAuth)
- App/RiffitApp.swift (onOpenURL, CollabJoinView overlay)
- Riffit.xcodeproj/project.pbxproj (registered all new files)

**Build status:** Zero errors confirmed
