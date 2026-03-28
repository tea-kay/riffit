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

### 2026-03-25 — Story Collaboration, Supabase persistence, auth fixes, wave splash

**What changed:**

*Story Collaboration — full 4-session build:*
- Session 1: StoryCollaborator + StoryInviteLink models, CollaboratorRole/CollaboratorStatus enums, SQL migration 003 (story_collaborators + story_invite_links tables, users.referred_by, story_notes.user_id, collaborator RLS)
- Session 2: Owner-side UI — CREATORS section in StoryDetailView, InviteSheet (invite link + username search + role picker), ManageCollaboratorsView
- Session 3: Collaborator-side UI — "Shared with me" section in StorybankView (pending/accepted rows, unread gold dot, accept/decline), CollabJoinView, permission-gated StoryDetailView, lastViewedAt tracking
- Session 4: Deep linking (onOpenURL, invite token resolution, referral attribution wiring in AppState + AuthViewModel)

*Supabase persistence — Storybank:*
- StorybankViewModel fully wired: stories, assets, sections, references, notes, folders all CRUD via optimistic UI + background Supabase calls
- SQL migration 004 (story_notes, asset_sections, story_folders, story_folder_map tables with RLS)
- Custom ISO 8601 date decoder (no .convertFromSnakeCase — models have explicit CodingKeys)

*Supabase persistence — Library (Ideas):*
- LibraryViewModel fully wired: inspiration_videos, comments, folders, tags, folder mappings all CRUD
- SQL migration 005 (idea_comments, idea_tags, idea_folder_map, user_tags tables with RLS)

*Auth & user fixes:*
- RiffitUser custom init(from:) with defaults for nullable columns (email→"", subscriptionTier→.free, onboardingComplete→false, createdAt→Date())
- AppState.fetchUser now uses custom ISO 8601 decoder instead of SDK default .value
- AppState.ensureCreatorProfile: auto-creates creator_profiles row on login (replaced broken database trigger)
- AppState.ensureDisplayName: auto-populates full_name from email prefix for new users
- handle_new_user trigger updated with subscription_tier and onboarding_complete defaults
- handle_new_creator_profile trigger removed (caused 500 on sign-up due to transaction timing)
- Master RLS fix: replaced all recursive creator_profiles join policies with direct auth.uid() = creator_profile_id
- RLS policy added: authenticated users can search other users (SELECT on public.users)
- InspirationVideo.savedAt CodingKey fixed: maps to "created_at" (actual Supabase column name)
- Debug email sign-up error logging added (full error type + description)

*Collaboration refinements:*
- Username search in InviteSheet now also matches on email (most users have null username/full_name)
- Collaborator rows show real user avatar/name from Supabase (CollaboratorUserInfo cache in StorybankViewModel)
- Role picker available on collaborator rows for all tiers (temporarily enabled for testing)
- CREATORS section label (was PEOPLE)
- Default initials avatar color standardized to teal600 across all views

*UI:*
- WaveSplashView loading screen: animated teal sine waves (4 layers, parallax) + gold shimmer on crests + Riffit wordmark + tagline. Fades out 0.4s when loading completes.
- specs/ folder created with TEMPLATE.md, EARN_REFERRAL_PROGRAM.md, STORY_COLLABORATION.md, README.md

**Decisions made:**
- All RLS policies use direct auth.uid() = creator_profile_id, never recursive joins through creator_profiles
- Creator profiles created on-demand at login (AppState.ensureCreatorProfile), not via database trigger
- handle_new_creator_profile trigger removed permanently — caused sign-up failures
- Collaborator username search includes email as fallback
- New users get full_name auto-populated from email prefix
- RiffitUser uses custom decoder with sensible defaults for all nullable Supabase columns
- Permission checks use CollaboratorRole computed properties — never duplicated in Views
- Deep link parsing in AppState.handleDeepLink, invite resolution in StorybankViewModel
- CollabJoinView is a ZStack overlay on RootView, not a sheet
- Referral attribution: first referrer wins
- Feature specs live in specs/ folder, read by Claude Code before building
- Migration SQL files deleted after running — no longer needed on disk

**Files created:**
- Models/StoryCollaborator.swift, Models/StoryInviteLink.swift
- Features/Storybank/InviteSheet.swift, ManageCollaboratorsView.swift, CollabJoinView.swift
- Components/WaveSplashView.swift
- specs/TEMPLATE.md, EARN_REFERRAL_PROGRAM.md, STORY_COLLABORATION.md, README.md

**Files modified:**
- Models/User.swift (referredBy, custom init(from:), memberwise init)
- Models/StoryNote.swift (userId, CodingKeys)
- Models/StoryFolder.swift (userId, CodingKeys)
- Models/InspirationVideo.swift (savedAt CodingKey → created_at)
- Models/IdeaComment.swift (userId, CodingKeys)
- Models/IdeaFolder.swift (userId, CodingKeys)
- App/AppState.swift (deep link handling, invite state, custom decoder, ensureCreatorProfile, ensureDisplayName)
- App/RiffitApp.swift (onOpenURL, CollabJoinView overlay, WaveSplashView)
- Features/Auth/AuthView.swift (error logging, referredBy)
- Features/Auth/AuthViewModel.swift (referral attribution)
- Features/Storybank/StorybankViewModel.swift (full Supabase persistence, collaboration, CollaboratorUserInfo cache)
- Features/Storybank/StorybankView.swift (Shared with me, userId params)
- Features/Storybank/StoryDetailView.swift (CREATORS section, permission gating, role picker, collaborator display)
- Features/Library/LibraryViewModel.swift (full Supabase persistence)
- Features/Library/LibraryView.swift, AddInspirationView.swift, InspirationDetailView.swift (userId params)
- Features/Storybank/AddReferenceView.swift (userId params)
- Features/Storybank/ManageCollaboratorsView.swift (collaborator display, role picker enabled)
- Components/RiffitButton.swift (ghost button style)

**Files deleted:**
- Migrations/003_story_collaboration.sql (run, no longer needed)
- Migrations/004_storybank_tables.sql (run, no longer needed)
- Migrations/005_library_tables.sql (run, no longer needed)
- Migrations/ directory removed

**Build status:** Zero errors confirmed

### 2026-03-25 / 2026-03-26 — Collaboration persistence + segmented Storybank UI

**What changed:**

*Step 1 — Invite link persistence (InviteSheet → Supabase):*
- InviteSheet no longer fabricates URLs from story ID prefixes. Copy/Share now INSERT a real StoryInviteLink row into `story_invite_links` via `StorybankViewModel.createInviteLink()`, then build the URL from the returned UUID token
- Token is a server-generated UUID (not a story ID substring)
- Existing active links are reused — `activeInviteLink(for:)` returns the most recent non-expired link from the local cache
- Added `fetchInviteLinks(for:)` — SELECTs from `story_invite_links` WHERE story_id matches, populates the local `inviteLinks` cache
- StoryDetailView `.onAppear` calls `fetchInviteLinks` for owners so existing links load from Supabase
- `resolveInviteToken` now falls through to a Supabase query when the token isn't in the local cache, then re-resolves
- Copy/Share buttons show a ProgressView spinner while the link is being created, and are disabled to prevent double-creates

*Step 2 — Collaboration mutations wired to Supabase:*
- `joinStoryFromInvite` — INSERT into `story_collaborators` + UPDATE `story_invite_links` use_count (two background Tasks)
- `addCollaborator` — INSERT into `story_collaborators` (background Task)
- `removeCollaborator` — DELETE FROM `story_collaborators` (background Task)
- `updateCollaboratorRole` — UPDATE `story_collaborators` SET role (background Task)
- `acceptInvite` — UPDATE `story_collaborators` SET status='accepted', accepted_at (background Task)
- `declineInvite` — DELETE FROM `story_collaborators` (background Task)
- `leaveStory` — DELETE FROM `story_collaborators` (background Task)
- `resolveInviteToken` — now fetches story title + owner display name/avatar from Supabase when the story isn't in local cache (for CollabJoinView display)
- All mutations follow the existing optimistic UI + background Task + print-on-error pattern

*Step 3 — Collaboration fetch on login (data survives app restart):*
- `fetchSharedStories()` implemented — SELECTs `story_collaborators` WHERE user_id = currentUser AND role != 'owner', then fetches the Story objects, assets, references, notes for those shared stories, and caches owner user info
- Shared stories are merged into the main `stories` array (for view lookup) but excluded from `unfiledStories` and `stories(in:)` via a `sharedStoryIds` computed property
- `fetchCollaborators(for:)` implemented — SELECTs `story_collaborators` WHERE story_id matches, populates `storyCollaboratorsMap`, caches user info
- `fetchStories()` updated — after owned stories load and `isLoading = false`, spawns a background Task that calls `fetchSharedStories()` then batch-fetches all collaborators for owned stories in a single query
- Added `currentUserId` private property so `fetchSharedStories()` can access the user ID without a parameter (since the view calls it with no args in `.refreshable`)

*Step 4 — Segmented Storybank UI:*
- Added "My stories" / "Shared" segmented control to StorybankView (custom-styled, not system Picker)
- Segmented control only appears when user has ≥1 pending invite or accepted shared story
- "My stories" (default): shows owned stories + folders, identical to the previous view
- "Shared": shows Pending section (gold label + count badge + redesigned invite cards) and Active section (teal label + shared story cards with real owner info)
- `PendingInviteCard` replaces `PendingInviteRow`: gold-tinted border, real inviter avatar + "@name invited you" + timestamp, story title in display font, counts, "Join story" (gold) + "Decline" (transparent) buttons
- `SharedStoryCard` updated: accepts real `ownerDisplayName` and `ownerAvatarUrl` from `collaboratorUserInfo` cache, 20pt owner avatar with AsyncImage, unread gold dot inline with timestamp
- Gold notification dot on "Shared" segment when pending invites exist
- `CardPressStyle` added — scaleEffect(0.97) on press with 0.1s easeInOut animation
- `StorybankSegment` enum and `StorybankSegmentedControl` custom view added
- Gold `.badge()` on Storybank tab in MainTabView (reactively shows/hides based on pending invite count)
- `UITabBarItem.appearance().badgeColor` set to gold (#F0AA20) — UIKit used because SwiftUI has no tab badge color API

*Step 5 — Bug fix: owned stories disappearing:*
- `sharedStoryIds` computed property now filters `sharedCollaborations` by `role != .owner` before building the exclusion set — prevents owned stories from being accidentally excluded from `unfiledStories`
- Added temporary debug prints to trace `stories` array mutations (fetchStories, fetchSharedStories removeAll, createStory, deleteStory, duplicateStory) — for console-based debugging of the disappearing stories issue

**Decisions made:**
- Invite link tokens are server-generated UUIDs, not derived from story IDs
- Existing active invite links are reused (one link per story unless expired/maxed)
- Shared stories are stored in the main `stories` array and excluded from owned-story views via `sharedStoryIds`
- `sharedStoryIds` filters by `role != .owner` as defense-in-depth
- Segmented control is custom SwiftUI (not system Picker) to match design system
- Tab badge color uses UIKit appearance proxy (no SwiftUI equivalent)

**Files created:**
- None (all changes within existing files)

**Files modified:**
- Features/Storybank/StorybankViewModel.swift (createInviteLink, fetchInviteLinks, activeInviteLink, fetchSharedStories, fetchCollaborators, joinStoryFromInvite, addCollaborator, removeCollaborator, updateCollaboratorRole, acceptInvite, declineInvite, leaveStory, resolveInviteToken, sharedStoryIds, unfiledStories, stories(in:), currentUserId, debug prints)
- Features/Storybank/InviteSheet.swift (getOrCreateInviteUrl, inviteUrl(for:), real invite link flow, loading state)
- Features/Storybank/StoryDetailView.swift (fetchInviteLinks on appear for owners)
- Features/Storybank/StorybankView.swift (StorybankSegmentedControl, segmented layout, PendingInviteCard, SharedStoryCard with real owner data, CardPressStyle, sharedSegmentContent, pendingSection, activeSection)
- App/MainTabView.swift (gold badge on Storybank tab, UITabBarItem badge color)

**Build status:** Zero errors confirmed

### 2026-03-27 — Collab persistence fixes, flicker bug, owner collaborator records

**What changed:**

*Collaboration debugging + fixes (be43c99, 6285179):*
- `fetchStories()` rewritten: Phase 1 fires owned stories + shared collab records in parallel (`async let`), Phase 2 fires all sub-data (assets, sections, refs, notes, folders, folder maps, shared story objects) in parallel — up to 10 concurrent queries
- Three code paths for Phase 2 based on data shape: owned+shared, owned-only, shared-only — avoids empty `IN ()` queries
- Added `hasLoadedOnce` and `hasLoadedSharedOnce` published bools to prevent empty state flicker
- Added `currentUserId` private property so `fetchSharedStories` logic is embedded in `fetchStories` (no separate call needed)
- `sharedStoryIds` computed property added — filters `sharedCollaborations` by `role != .owner` to build exclusion set for owned story views
- `unfiledStories` and `stories(in:)` now exclude shared stories via `sharedStoryIds`
- `refreshable` on StorybankView simplified — only calls `fetchStories` (shared fetch is now integrated)
- `resolveInviteToken` falls through to Supabase query when token isn't in local cache
- StoryDetailView `userRole` now checks `creatorProfileId == currentUser.id` as fallback when no collaborator record exists (fixes owner seeing viewer permissions)
- StoryDetailView `.onAppear` now calls `fetchCollaborators(for:)` from Supabase instead of `ensureOwnerCollaborator` — People section populated from real data

*Storybank flicker bug fix (341833e):*
- StorybankView loading state changed: shows `Color.clear` instead of `ProgressView` while `!hasLoadedOnce` — prevents empty state from flashing before data arrives (<200ms load)

*Owner collaborator records (unstaged):*
- `createStory()` now auto-creates an owner `StoryCollaborator` record both locally and in Supabase — People section works immediately without needing `ensureOwnerCollaborator`
- `ensureOwnerCollaborator()` removed — owner records are now created at story creation time and fetched by `fetchCollaborators()`
- StoryDetailView `.onAppear` simplified: fetches collaborators from Supabase, fetches invite links for owners, tracks last viewed for non-owners

**Decisions made:**
- `fetchStories` is now a single unified fetch that loads owned + shared data in two parallel phases
- Owner collaborator records created at story creation time (not lazily on detail view open)
- `ensureOwnerCollaborator` removed — redundant with proper record creation
- Empty state flicker solved with `hasLoadedOnce` flag + Color.clear (not ProgressView)

**Files created:**
- None

**Files modified:**
- Features/Storybank/StorybankViewModel.swift (fetchStories rewrite, createStory owner collab, sharedStoryIds, hasLoadedOnce, ensureOwnerCollaborator removed)
- Features/Storybank/StoryDetailView.swift (userRole fallback, onAppear simplified, fetchCollaborators call)
- Features/Storybank/StorybankView.swift (flicker fix, segmented control, refreshable simplified)

**Build status:** Zero errors confirmed

### 2026-03-27 — People section owner fix, iMessage-style notes, segmented picker light mode, ghost button light mode

**What changed:**

*People section — owner display fix:*
- CollaboratorRow display name/avatar now branches on `collaborator.userId == currentUser.id` instead of `collaborator.role == .owner` — fixes bug where the current user's name/avatar showed on the actual owner's row when a collaborator views a shared story
- User info cache trigger updated to match: caches info for `userId != currentUser.id` instead of `role != .owner`
- Renamed `ownerCollabDisplayName` → `currentUserDisplayName` (role-agnostic)

*iMessage-style note/comment bubbles:*
- Own messages: right-aligned, primary tint (gold) background, no avatar/name, less-rounded bottom-right corner, timestamp below bubble trailing-aligned
- Others' messages: left-aligned, surface background, avatar + name + timestamp above bubble, less-rounded bottom-left corner
- Added `RoundedCornerShape` (per-corner radius) to StoryDetailView for iMessage-style asymmetric corners
- Own note text uses `textPrimary` color (brighter on gold tint), others use `textSecondary`
- Same treatment applied to `CommentBubble` in InspirationDetailView for idea comments
- Extracted `notesContent` and `noteBubbleRow(for:)` from StoryDetailView body to fix Swift type-checker complexity limit
- Added `collaboratorAvatarUrl(forUserId:)` to StorybankViewModel for direct user ID lookup

*Segmented picker light mode fix:*
- Selected tab: `Color.riffitSurface` + shadow → `Color.riffitPrimaryTint` (gold tint), `.fontWeight(.semibold)`
- Unselected tab: transparent, `.fontWeight(.regular)`
- Outer pill: `Color.riffitElevated` → `Color.riffitSurface` with `Color.riffitBorderSubtle` stroke — visible shape in light mode

*Ghost button light mode fix:*
- `RiffitGhostGoldButtonStyle` had hardcoded `Color(hex: 0x111111)` for resting fill and pressed text — dark mode appearance in light mode
- Replaced with `Color.riffitBackground` — adapts to `#111111` dark / `#F5F2EB` light

**Files modified:**
- Features/Storybank/StoryDetailView.swift (People section userId check, iMessage note bubbles, RoundedCornerShape, notesContent extraction)
- Features/Library/InspirationDetailView.swift (iMessage comment bubbles, CommentBubble rewrite)
- Features/Storybank/StorybankViewModel.swift (collaboratorAvatarUrl(forUserId:) helper)
- Features/Storybank/StorybankView.swift (segmented picker light mode colors)
- Components/RiffitButton.swift (ghost gold button light mode fix)

**Build status:** Zero errors confirmed

### 2026-03-27 — Storybank folders → dropdown picker, story card context menu

**What changed:**

*Folder UI overhaul:*
- Removed inline folder rows (StoryFolderRow, StoryFolderDropTarget) from the Storybank story list
- Removed drag-to-organize on story cards (`.draggable` modifier)
- Replaced horizontal folder filter pills with a compact `Menu` dropdown picker
- Picker sits between segmented control and story list, shows "All stories" or active folder name + chevron.down
- Menu contents: "All stories" (checkmark when active) → divider → each folder (checkmark on active) → divider → "New Folder" (plus icon)
- When a specific folder is selected, Rename and Delete options appear at the bottom of the menu
- Folder rename/delete trigger existing `RiffitInputModal` and `RiffitConfirmModal` flows
- Deleting the currently-selected folder resets filter to "All stories"

*Story card context menu:*
- Long-press on any StoryCard now shows "Move to folder" submenu with all available folders
- Active folder shows checkmark.circle.fill icon, others show folder icon
- "Remove from folder" option appears when story is already in a folder

*Styling:*
- Picker label: SF Pro 14pt medium weight, text secondary when "All stories", text primary when filtered
- Chevron: system 10pt, text tertiary
- No background, no border — subtle context indicator

**Decisions made:**
- StoryFolderDetailView kept as dead code (navigable via deep link, not from main list)
- Folder CRUD moved from inline pills to inside the dropdown menu
- Drag-to-organize removed entirely — folder assignment via context menu only

**Files modified:**
- Features/Storybank/StorybankView.swift (folder picker, story card context menu, removed StoryFolderRow, StoryFolderDropTarget, folder filter pills)
- Features/Storybank/StorybankViewModel.swift (added `isSharedStory()` public method)

**Build status:** Zero errors confirmed

### 2026-03-27 — RiffitConfirmationModal, delete story confirm, loading flicker fix, folder empty state

**What changed:**

*RiffitConfirmationModal component:*
- Created reusable `RiffitConfirmationModal` in `Components/RiffitConfirmationModal.swift` — replaces all native `.alert()` confirmation prompts app-wide
- Supports destructive (coral confirm button) and non-destructive (gold confirm button) modes via `isDestructive` parameter
- Presented via existing `.riffitModal(isPresented:)` overlay with spring animation + dimmed backdrop
- Replaced 9 native alerts across 7 files: Leave Story (×2), Delete Folder (×3), Remove Collaborator, Sign Out, Delete Idea (×2)
- Removed old `RiffitConfirmModal` from `View+Riffit.swift` (fully superseded)
- Added component pattern documentation to `DESIGN_SYSTEM_UPDATE.md`
- Added "never use native alerts for confirmations" rule to `CLAUDE.md`

*Delete story confirmation:*
- "Delete Story" toolbar button in StoryDetailView now triggers a `RiffitConfirmationModal` instead of directly calling `deleteStory()` (was the only destructive action without a confirmation)
- Fixed dismiss ordering: modal closes → navigation pops → delete runs on next run loop tick via `DispatchQueue.main.async` (prevents ghost card in list)

*View loading standard (hasLoadedOnce pattern):*
- Added `hasLoadedOnce` to `LibraryViewModel` — first fetch shows `Color.clear`, subsequent refreshes are silent (no spinner flash)
- Updated `LibraryView` to use `!viewModel.hasLoadedOnce` → `Color.clear` instead of `isLoading && isEmpty` → `ProgressView()`
- Fixed `StorybankViewModel.fetchStories()` to only set `isLoading = true` on first fetch (was showing loading on every refresh)
- Documented the pattern in `DESIGN_SYSTEM_UPDATE.md` (View Loading Standard) and `CLAUDE.md` (SwiftUI Patterns + Never Do rules)

*Folder empty state:*
- Added filtered empty state for when a folder is selected but contains no stories
- Ripple rings illustration (`FolderEmptyRipple`): Canvas-drawn concentric elliptical rings (teal 900/600/400), gold drop point at center with glow, teal accent dots, star accents
- Layout matches Ideas and Storybank main empty states exactly: same VStack(spacing: 0), Spacer/Spacer centering, RS.lg/RS.sm/RS.lg spacing, RF.heading/RF.caption fonts, RS.xl2 button padding
- Ghost gold "Start a new story" button auto-assigns the new story to the currently selected folder via `newStoryFolderId` state
- Illustration scaled to fill 180×140 frame proportionally (outermost ring rx=160 ry=100, matching visual weight of wave barrel and gem illustrations)

**Decisions made:**
- Native `.alert()` and `.confirmationDialog()` banned for confirmation prompts — always use `RiffitConfirmationModal`
- Empty state or loading spinner before first fetch banned — always use `hasLoadedOnce` pattern
- Delete story requires confirmation modal (was the only unguarded destructive action)
- Folder empty state uses same vertical rhythm as main empty states for visual consistency

**Files created:**
- Components/RiffitConfirmationModal.swift

**Files modified:**
- Core/Extensions/View+Riffit.swift (removed old RiffitConfirmModal)
- Features/Storybank/StorybankView.swift (Leave Story alert → modal, folder delete modals → RiffitConfirmationModal, folder empty state with ripple illustration, newStoryFolderId state)
- Features/Storybank/StoryDetailView.swift (Leave Story alert → modal, delete story confirmation added, dismiss ordering fix)
- Features/Storybank/ManageCollaboratorsView.swift (Remove Collaborator alert → modal)
- Features/Settings/SettingsView.swift (Sign Out alert → modal)
- Features/Library/InspirationDetailView.swift (Delete Idea alert → modal)
- Features/Library/LibraryView.swift (Delete Idea alert → modal, hasLoadedOnce loading pattern)
- Features/Library/FolderDetailView.swift (Delete Folder → RiffitConfirmationModal)
- Features/Library/LibraryViewModel.swift (hasLoadedOnce, silent refresh on subsequent fetches)
- Features/Storybank/StorybankViewModel.swift (silent refresh on subsequent fetches)
- CLAUDE.md (confirmation modal rule, hasLoadedOnce rules, SwiftUI pattern example)
- DESIGN_SYSTEM_UPDATE.md (RiffitConfirmationModal spec, View Loading Standard)
- Riffit.xcodeproj/project.pbxproj (added RiffitConfirmationModal.swift)

**Build status:** Zero errors confirmed
