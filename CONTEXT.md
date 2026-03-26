# Riffit — Current State

> **Overwrite this file at the end of each session.**
> This is the current state of the codebase — not a history.
> For the changelog, see CHANGES.md.
> For architecture and rules, see CLAUDE.md.
>
> Last updated: 2026-03-25

---

## Product State

MVP v1 — solo creator tool with multi-user collaboration. Supabase fully connected: auth, stories, ideas, and collaboration all persist across app restarts. No AI features yet.

### What Works
- **Auth:** Sign in with Apple → auto-creates user row → routes to main app. Session persists to Keychain. Sign out clears everything. New users get full_name auto-populated from email prefix.
- **Supabase persistence:** All data survives app relaunch — stories, assets, sections, references, notes, folders, ideas, comments, tags, folder mappings. Optimistic UI + background Supabase calls.
- **Library (Ideas):** Save ideas from Instagram, YouTube, TikTok, X/Twitter, LinkedIn. Platform auto-detection, browse/search/filter by tag, edit, organize in folders. Delete with orphaned reference cleanup. All persisted.
- **Storybank:** Create stories with text, voice, image, video assets. Organize into named sections with drag reorder. Add idea references linked to sections. Duplicate stories (full deep copy). All persisted.
- **Media:** Record voice notes (press-and-hold), take/pick photos, record/pick videos. Playback and export to Camera Roll or share as files. Media files stored locally (metadata only in Supabase).
- **Story Collaboration:**
  - Owner: CREATORS section in StoryDetailView with role pills, InviteSheet (link copy/share + username/email search), ManageCollaboratorsView (role change, remove, count vs limit)
  - Collaborator: "Shared with me" section in StorybankView (pending invites with Accept/Decline, accepted stories with owner attribution + role pill + unread gold dot)
  - CollabJoinView: full-screen invite landing with error states (expired/not found/already member)
  - Permission-gated StoryDetailView: all UI gated by CollaboratorRole (owner/editor/viewer/commenter/collaborator)
  - Deep link handling: .onOpenURL parses riffit.app/invite/{token}, resolves invite, shows CollabJoinView overlay
  - Referral attribution: invite links carry referral_user_id, set as referred_by on new user creation
  - Unread tracking: lastViewedAt updated on story open, gold dot when new notes exist
  - Collaborator rows show real avatar + display name from Supabase (CollaboratorUserInfo cache)
- **Notes threads** on both ideas and stories (with avatar + inline editing)
- **Settings:** Account management, appearance, influences analytics. Profile photo upload, editable name/username.
- **Wave splash screen:** Animated teal sine waves + gold Riffit wordmark on launch, fades out when loaded
- **Design system:** All colors via RiffitColors tokens, fonts via RiffitTheme, spacing from RS constants

### What Doesn't Work Yet
- No onboarding flow (creator type selection, AI interview)
- No RevenueCat / subscription logic
- No share extension (file exists but is scaffolding)
- No AI features (all dormant in EdgeFunctions.swift)
- No tests, no CI
- CreatorProfile, VideoDeconstruction models exist but aren't fully used
- Earn feature (referral program) specced but not built
- Apple App Site Association file not deployed (needed for universal links in production)
- Media files stored locally only — not uploaded to Supabase Storage
- Collaborator limit enforcement is UI-side only (server enforcement not wired)

---

## Referral Program (Earn) — Specced, Not Yet Built

3-level deep referral commission system. To be added to Settings between Creative and App sections.

**Commission rates (locked):**
- Level 1 (direct referral): 50% first month, then 10% recurring
- Level 2 (referral's referral): 3% recurring, starts month 2
- Level 3 (three levels deep): 1% recurring, starts month 2
- $100/mo cap per referred account at all levels
- Lifetime commissions as long as referred user stays subscribed
- Everyone can refer; commissions only on paid subscriptions

**Files to create:** EarnView.swift, EarnViewModel.swift
**File to modify:** SettingsView.swift (add Earn section row)

---

## Decisions That Stick (Do Not Re-Add Without Being Asked)

### Removed Features
- AI alignment scoring, brief generation, onboarding interview, relevance notes, auto-generated summaries
- Auto-fetch video metadata on URL paste
- Video stats (views/likes/comments)
- AlignmentBadge, ShimmerBlock, StatField components
- Briefs tab
- handle_new_creator_profile database trigger (caused sign-up 500 errors)

### Architecture Decisions
- All RLS policies use direct `auth.uid() = creator_profile_id` pattern, never recursive joins through `creator_profiles`
- Creator profiles created on-demand at login (AppState.ensureCreatorProfile), not via database trigger
- RiffitUser uses custom `init(from:)` decoder with sensible defaults for all nullable Supabase columns
- AppState.fetchUser uses custom ISO 8601 date decoder (not SDK default)
- New users get full_name auto-populated from email prefix (AppState.ensureDisplayName)
- Supabase keys live in Config.xcconfig (gitignored), never hardcoded in Swift
- Auth: ASAuthorization → signInWithIdToken (not Supabase OAuth redirect)
- AppState owns auth state via supabase.auth.authStateChanges async stream
- StorybankViewModel and LibraryViewModel use optimistic UI + background Supabase Tasks
- Permission checks use CollaboratorRole computed properties — never duplicated in Views
- Deep link parsing in AppState.handleDeepLink, invite resolution in StorybankViewModel.resolveInviteToken
- CollabJoinView is a ZStack overlay on RootView (not a sheet)
- Referral attribution: first referrer wins (referred_by only set if nil)
- Username search in InviteSheet includes email as fallback
- Feature specs live in specs/ folder, read by Claude Code before building
- YouTube and X use thumbnail + deep link (both block WKWebView embeds)
- TikTok uses embed URL in WKWebView with 9:16 aspect ratio
- Tags are user-manageable (create/delete any tag, including defaults)
- Asset sections use flat list approach with cross-section drag reorder
- Media files stored locally in Documents/{voice_notes,images,videos}/
- Default initials avatar: teal600 background everywhere
- Migration SQL files deleted after running — not kept on disk

---

## Models
InspirationVideo    — id, creatorProfileId, url, platform, title?, userNote?,
                      thumbnailUrl?, transcript?, alignmentScore?, alignmentVerdict?,
                      alignmentReasoning?, status (saved/archived), savedAt (maps to created_at)

IdeaComment         — id, inspirationVideoId, userId?, authorName, text (var), createdAt
IdeaFolder          — id, userId?, name, createdAt

Story               — id, creatorProfileId, title, status (draft/ready/archived),
                      createdAt, updatedAt
StoryAsset          — id, storyId, assetType (voiceNote/video/image/text), name?,
                      sectionId?, contentText?, fileUrl?, durationSeconds?,
                      displayOrder, createdAt
StoryReference      — id, storyId, inspirationVideoId, referenceTag,
                      aiRelevanceNote?, displayOrder, createdAt
StoryNote           — id, storyId, userId?, authorName, text (var), createdAt
StoryFolder         — id, userId?, name, createdAt
AssetSection        — id, storyId, name, displayOrder, createdAt

StoryCollaborator   — id, storyId, userId, role (owner/editor/viewer/commenter/collaborator),
                      invitedBy?, status (pending/accepted/declined), createdAt,
                      acceptedAt?, lastViewedAt?
StoryInviteLink     — id, storyId, createdBy, role, referralUserId?, token (unique),
                      expiresAt?, maxUses?, useCount, createdAt

CollaboratorUserInfo — displayName, avatarUrl? (in-memory cache on StorybankViewModel)

---

## File Structure
Riffit/
├── App/
│   ├── RiffitApp.swift
│   ├── AppState.swift
│   └── MainTabView.swift
├── Core/
│   ├── Audio/
│   │   ├── AudioRecorderService.swift
│   │   └── AudioPlayerService.swift
│   ├── Design/
│   │   ├── RiffitColors.swift
│   │   └── RiffitTheme.swift
│   ├── Extensions/
│   │   ├── PlatformDetector.swift
│   │   └── View+Riffit.swift
│   ├── Media/
│   │   ├── AssetExportService.swift
│   │   ├── CameraPickerView.swift
│   │   ├── ImageStorageService.swift
│   │   ├── VideoPickerView.swift
│   │   └── VideoStorageService.swift
│   └── Network/
│       ├── EdgeFunctions.swift
│       └── SupabaseClient.swift
├── Models/
│   ├── AssetSection.swift
│   ├── CreatorProfile.swift
│   ├── IdeaComment.swift
│   ├── IdeaFolder.swift
│   ├── InspirationVideo.swift
│   ├── Story.swift
│   ├── StoryAsset.swift
│   ├── StoryCollaborator.swift
│   ├── StoryFolder.swift
│   ├── StoryInviteLink.swift
│   ├── StoryNote.swift
│   ├── StoryReference.swift
│   ├── User.swift
│   └── VideoDeconstruction.swift
├── Config.xcconfig
├── Components/
│   ├── FlowLayout.swift
│   ├── InspirationCard.swift
│   ├── LoadingOverlay.swift
│   ├── RiffitButton.swift
│   ├── RiffitWordmark.swift
│   ├── ShareSheet.swift
│   └── WaveSplashView.swift
├── Features/
│   ├── Auth/
│   │   ├── AuthView.swift
│   │   └── AuthViewModel.swift
│   ├── Library/
│   │   ├── AddInspirationView.swift
│   │   ├── FolderDetailView.swift
│   │   ├── InspirationDetailView.swift
│   │   ├── LibraryView.swift
│   │   └── LibraryViewModel.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingViewModel.swift
│   │   └── Steps/
│   │       ├── CreatorTypeView.swift
│   │       ├── InterviewView.swift
│   │       └── SocialConnectView.swift
│   ├── Settings/
│   │   ├── AccountView.swift
│   │   ├── EarnView.swift
│   │   ├── EarnViewModel.swift
│   │   ├── InfluencesView.swift
│   │   └── SettingsView.swift
│   └── Storybank/
│       ├── AddReferenceView.swift
│       ├── CollabJoinView.swift
│       ├── ImageAttachmentSheet.swift
│       ├── ImageViewerView.swift
│       ├── InviteSheet.swift
│       ├── ManageCollaboratorsView.swift
│       ├── StorybankView.swift
│       ├── StorybankViewModel.swift
│       ├── StoryDetailView.swift
│       ├── VideoAttachmentSheet.swift
│       ├── VideoPlayerView.swift
│       ├── VoiceNotePlayerView.swift
│       └── VoiceNoteRecordSheet.swift
└── ShareExtension/
    └── ShareViewController.swift

---

## Supabase Schema (all tables live, all migrations applied)

**Original 7 tables:**
- `users` — mirrors auth.users, auto-created via trigger, has referred_by + username columns
- `creator_profiles` — brand brain (created on-demand by AppState.ensureCreatorProfile)
- `inspiration_videos` — saved ideas from any platform
- `inspiration_folders` — folder organization for ideas (has user_id column)
- `stories` — creative workspace entries
- `story_assets` — media/text attached to stories
- `story_references` — links stories to inspiration videos

**Migration 003 — Story Collaboration:**
- `story_collaborators` — collaboration records with role + status + lastViewedAt
- `story_invite_links` — shareable invite tokens with referral attribution
- `users.referred_by` column, `story_notes.user_id` column
- RLS policies for collaborator access on story_assets, story_references, story_notes

**Migration 004 — Storybank supporting tables:**
- `story_notes` — notes thread on stories
- `asset_sections` — named groupings within stories
- `story_folders` — folder organization for stories (has user_id)
- `story_folder_map` — maps stories to folders

**Migration 005 — Library supporting tables:**
- `idea_comments` — comment threads on ideas
- `idea_tags` — per-video tag assignments
- `idea_folder_map` — maps ideas to folders
- `user_tags` — user's custom tag list

**Master RLS fix applied:** All policies use `auth.uid() = creator_profile_id` directly, not recursive joins.

---

## Info.plist Keys

- `NSMicrophoneUsageDescription` — voice note recording
- `NSCameraUsageDescription` — photo/video capture
- `NSPhotoLibraryUsageDescription` — photo/video selection
- `NSPhotoLibraryAddUsageDescription` — saving to Camera Roll
- `UIAppFonts` — Lora (Regular/Medium/Bold/Italic), DM Sans (Light/Regular/Medium)

---

## StoryDetail Toolbar Menu Order (Owner)

Rename → Archive → Share → Save All Assets → Duplicate → Manage People → Compose (greyed) → Divider → Delete Story (destructive)

## StoryDetail Toolbar Menu Order (Non-Owner)

Share → Save All Assets (if canDownload) → Divider → Leave Story (destructive)
