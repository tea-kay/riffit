# Riffit — Current State

> **Overwrite this file at the end of each session.**
> This is the current state of the codebase — not a history.
> For the changelog, see CHANGES.md.
> For architecture and rules, see CLAUDE.md.
>
> Last updated: 2026-03-25

---

## Product State

MVP v1 — solo creator tool, no AI. Supabase connected with Apple Sign In auth working.
User data persists in Supabase (auth session, user record). Library/Storybank data is still in-memory (resets on relaunch — persistence migration pending).

### What Works
- Supabase connected: 7 tables with RLS, auth via Apple Sign In, session persists to Keychain
- Sign in with Apple → auto-creates user row → routes to main app
- Sign out works → clears session → routes back to AuthView
- Settings shows real user data from Supabase (name, email, avatar, subscription tier)
- Save ideas from Instagram, YouTube, TikTok, X/Twitter, LinkedIn (URL + title + note + tags + folder)
- Platform auto-detection from URL with dynamic icon/label
- Browse, search, filter by tag, edit, and organize ideas in folders
- Delete ideas with confirmation (cleans up orphaned story references)
- YouTube: thumbnail + deep link to YouTube app/Safari (WKWebView blocked)
- TikTok: vertical 9:16 embed via WKWebView
- X/Twitter: thumbnail or placeholder card + deep link to X app/Safari
- Instagram/LinkedIn: standard WKWebView embed
- Create stories with text, voice, image, and video assets
- Organize assets into named sections with drag reorder
- Add idea references to stories (linked to sections)
- Record voice notes (press-and-hold), take/pick photos, record/pick videos
- Play back voice notes, view images, play videos from asset rows
- Export assets to Camera Roll or share as files
- Duplicate stories (full deep copy: assets, sections, references, notes)
- Share story title via ShareSheet
- Notes threads on both ideas and stories (with avatar + inline editing)
- Folder organization in both Library and Storybank
- Settings with account management, appearance, influences analytics
- Profile photo upload, editable name/username with display name logic
- Author avatar on story cards
- InspirationCard: platform label top-left, timestamp top-right, avatar trailing in footer
- Empty states aligned across tabs (same vertical positions)
- RiffitGhostButtonStyle on empty state CTAs (black/gold, inverts on press)
- Compose menu item (greyed out, v2 AI placeholder)
- Idea title changes persist back to list (Equatable fix)

### What Doesn't Work Yet
- Library and Storybank data is in-memory — not yet persisted to Supabase
- No onboarding flow
- No RevenueCat / subscription logic
- No share extension (file exists but is scaffolding)
- No AI features (all dormant in EdgeFunctions.swift)
- No tests, no CI
- CreatorProfile, VideoDeconstruction models exist but aren't used
- Earn feature (referral program) specced but not built

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
- AI alignment scoring (score, verdict, badge, shimmer states)
- AI brief generation, onboarding interview, relevance notes
- Auto-generated video summaries
- Auto-fetch video metadata on URL paste
- Video stats (views/likes/comments) — fields in Supabase, not in Swift
- AlignmentBadge component (deleted), ShimmerBlock component, StatField component
- Briefs tab

### Architecture Decisions
- Supabase keys live in Config.xcconfig (gitignored), never hardcoded in Swift
- Auth: ASAuthorization → signInWithIdToken (not Supabase OAuth redirect)
- AppState owns auth state via supabase.auth.authStateChanges async stream
- Settings pulls user data from AppState.currentUser — no separate network calls
- YouTube and X use thumbnail + deep link (both block WKWebView embeds)
- TikTok uses embed URL in WKWebView with 9:16 aspect ratio
- Platform detection lives in PlatformDetector helper, never in View body
- InspirationVideo Equatable compares id + title + status (not id-only — SwiftUI needs mutable field changes to re-render)
- References use the story's actual sections, not a hardcoded 6-tag picker
- Folder picker uses Menu with .contentShape(Rectangle()) — never invisible overlay hacks
- Tags are user-manageable (create/delete any tag, including defaults)
- `availableTags` on LibraryViewModel replaces static `IdeaTag.defaults`
- StorybankViewModel is shared via @EnvironmentObject from MainTabView
- Asset sections use flat list approach (interleaved ForEach, not multiple SwiftUI Sections)
- Section headers are draggable (`.moveDisabled(true)` creates barriers — don't use it)
- Media files stored in Documents/{voice_notes,images,videos}/ with UUID names
- Profile data uses @AppStorage with "riffit_" prefix keys
- Display name: @username if set, else fullName, else "You"
- Sheet backgrounds: always use `.presentationBackground(Color.riffitBackground)`
- Modals: centered overlay with dim background (never UIAlertController or .actionSheet)
- Deleting an idea cleans up all orphaned story references via StorybankViewModel.removeReferences(for:)
- RiffitGhostButtonStyle for empty state CTAs (black fill/gold text, inverts on press)

---

## Models
InspirationVideo    — id, creatorProfileId, url, platform, title?, userNote?,
                      thumbnailUrl?, transcript?, alignmentScore?, alignmentVerdict?,
                      alignmentReasoning?, status (saved/archived), savedAt

IdeaComment         — id, inspirationVideoId, authorName, text (var), createdAt
IdeaFolder          — id, name, createdAt

Story               — id, creatorProfileId, title, status (draft/ready/archived),
                      createdAt, updatedAt
StoryAsset          — id, storyId, assetType (voiceNote/video/image/text), name?,
                      sectionId?, contentText?, fileUrl?, durationSeconds?,
                      displayOrder, createdAt
StoryReference      — id, storyId, inspirationVideoId, referenceTag,
                      aiRelevanceNote?, displayOrder, createdAt
StoryNote           — id, storyId, authorName, text (var), createdAt
StoryFolder         — id, name, createdAt
AssetSection        — id, storyId, name, displayOrder, createdAt

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
│   ├── StoryFolder.swift
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
│   └── ShareSheet.swift
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
│   │   ├── InfluencesView.swift
│   │   └── SettingsView.swift
│   └── Storybank/
│       ├── AddReferenceView.swift
│       ├── ImageAttachmentSheet.swift
│       ├── ImageViewerView.swift
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

## Supabase Schema (live in dev project)

7 tables, all with RLS enabled:
- `users` — mirrors auth.users, auto-created via trigger
- `creator_profiles` — brand brain (niche, tone, pillars)
- `inspiration_videos` — saved ideas from any platform
- `inspiration_folders` — folder organization
- `stories` — creative workspace entries
- `story_assets` — media/text attached to stories
- `story_references` — links stories to inspiration videos

---

## Info.plist Keys

- `NSMicrophoneUsageDescription` — voice note recording
- `NSCameraUsageDescription` — photo/video capture
- `NSPhotoLibraryUsageDescription` — photo/video selection
- `NSPhotoLibraryAddUsageDescription` — saving to Camera Roll
- `UIAppFonts` — Lora (Regular/Medium/Bold/Italic), DM Sans (Light/Regular/Medium)

---

## StoryDetail Toolbar Menu Order

Rename → Archive → Share → Save All Assets → Duplicate → Compose (greyed) → Divider → Delete Story (destructive)
