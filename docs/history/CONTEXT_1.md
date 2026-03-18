# Riffit — Context 1

> Session context covering all features built since CONTEXT_0.
> Read alongside CLAUDE.md, CONTEXT_0.md, and DESIGN_SYSTEM_UPDATE.md.
> Last updated: 2026-03-18

---

## What Changed Since CONTEXT_0

CONTEXT_0 covered the initial Library, Storybank, empty states, auth,
and the removal of all AI features. This document covers everything
built after that point.

---

## Features Built (This Session)

### Library — Ideas

#### InspirationVideo Model Changes
- Removed `summary` field (was AI-generated) — replaced with `title`
- Added `title: String?` — manual entry from capture sheet
- Status enum simplified: `pending/analyzing/analyzed/archived` → `saved/archived`
- Removed `viewCount`, `likeCount`, `commentCount`, `statSource` fields entirely
- Fields still exist in Supabase schema — just not used in Swift

#### InspirationCard Title Logic
Card title hierarchy (no AI):
1. `video.title` (from manual entry)
2. First 8 words of `video.userNote`
3. Platform name + "reel" as last resort

Card layout: platform label → title → tag pills → "Your take" note → archived tag
No stats row, no alignment badge, no shimmer states.

#### Capture Sheet (AddInspirationView)
- URL field + manual title field + "Your take" note + tag pills + folder picker
- Stats section removed entirely (views/likes/comments inputs gone)
- `StatField` component deleted
- Tags are user-manageable: tap to toggle, long-press to delete, + button to create custom
- Tags stored in `LibraryViewModel.availableTags` (starts with defaults, fully mutable)
- Folder picker: `Menu` with `.contentShape(Rectangle())` — native dropdown, full-width row

#### Idea Detail (InspirationDetailView)
- Editable title field at top (saves to viewModel on change)
- Interactive tag section: all available tags shown, tap to toggle, + to create custom
- Uses `FlowLayout` (custom SwiftUI Layout) for wrapping tag pills
- Notes section with avatar + display name on each bubble
- Inline note editing: tap note → TextEditor replaces Text, Save/Cancel buttons appear
- Note author identity reads from `@AppStorage` (riffit_full_name, riffit_username, riffit_profile_image)

#### Folders
- Library has folders with drag-to-organize (draggable idea rows, drop targets on folders)
- FolderDetailView for browsing inside a folder
- AddReferenceView shows folders when picking an idea (folder rows at top, unfiled below)

### Storybank

#### Story Folders
- StoryFolder model (same pattern as IdeaFolder)
- Folder CRUD in StorybankViewModel (create, rename, delete, moveStory)
- Drag stories onto folders to organize
- StoryFolderDetailView for browsing inside a folder
- + button opens action modal: "New Story" / "New Folder"

#### Asset Sections
- AssetSection model: id, storyId, name, displayOrder
- StoryAsset gained `sectionId: UUID?` (nil = unsectioned)
- Flat list approach: computed `flatRows` array interleaves section headers and assets
- Single `ForEach` with `.onMove` — after drag, walks array top-to-bottom reassigning sectionIDs
- Section headers are draggable (removing `.moveDisabled(true)` was required for cross-section drag)
- Add/rename/delete sections via modals
- Deleting a section unfiles its assets (sets sectionId = nil), doesn't delete them

#### References
- Add Reference flow: pick idea → pick section (if story has sections) or add directly (if no sections)
- No hardcoded 6-tag picker — references use the story's actual sections
- `referenceTag` stores section name (or empty string for unsectioned)
- Reference card shows: section pill (teal, if set) + idea tags (gold) on same line, then title
- Long-press to delete (context menu only — no prominent delete button)
- Drag to reorder references

#### Voice Notes (Functional)
- `AudioRecorderService` — wraps AVAudioRecorder, saves m4a to Documents/voice_notes/
- `AudioPlayerService` — wraps AVAudioPlayer, play/pause/stop with live progress
- `VoiceNoteRecordSheet` — press-and-hold to record, preview screen with editable title, playback, save/discard
- `VoiceNotePlayerView` — full-screen player with editable title, progress bar, play/pause
- Voice note title defaults to "Voice Note — Mar 17, 2026" format

#### Image Attachments (Functional)
- `ImageStorageService` — saves JPEG to Documents/images/ with UUID filenames
- `CameraPickerView` — UIViewControllerRepresentable for camera
- `PhotoLibraryPickerView` — PHPickerViewController wrapper for photo library
- `ImageAttachmentSheet` — source picker (Take Photo / Choose from Library) → preview with editable title
- `ImageViewerView` — full-screen viewer with editable title
- Image thumbnails shown in asset rows (32×32 circular crop from local file)

#### Video Attachments (Functional)
- `VideoStorageService` — copies video to Documents/videos/, generates thumbnails from first frame
- `VideoCameraPickerView` — UIImagePickerController for video recording (60s max, medium quality)
- `VideoLibraryPickerView` — PHPickerViewController filtered to videos
- `VideoAttachmentSheet` — source picker → preview with AVPlayer (no autoplay), editable title
- `VideoPlayerView` — full-screen player with editable title
- Video thumbnails shown in asset rows
- Record option visible on all devices, disabled with "Camera not available" on simulator

#### Asset Export
- `AssetExportService` — exports to Camera Roll (images/videos/audio) or temp .txt for sharing
- Single asset: long-press context menu → "Save to Device"
- All assets: toolbar ⋯ menu → "Save All Assets"
- `ShareSheet` — UIActivityViewController wrapper for text file sharing
- Permission handling with alert directing to Settings

#### Story Notes
- `StoryNote` model (same pattern as IdeaComment but scoped to stories)
- NOTES section below REFERENCES in StoryDetailView
- Avatar + display name on each note bubble (reads from @AppStorage)
- Inline editing (tap to edit, Save/Cancel)
- "Add a note..." input with send button
- Timestamp: "You · Just now" / "You · 6h ago" format

### Settings

#### SettingsView (Full Restructure)
Sections in order:
1. **Account card** — avatar, name, "Creator · Free plan", Free badge, chevron → navigates to AccountView
2. **Plan** — "Riff Pro" with Upgrade badge, "Current usage" with hardcoded counts
3. **Creative** — "Creator profile" (placeholder), "Your influences" → InfluencesView
4. **App** — Appearance (existing, preserved)
5. **Legal** — Privacy policy, Terms of service (placeholders), Version (bundle string)
6. **Sign out** — danger button with confirmation alert (no-op)

#### AccountView
- Interactive avatar: tap opens PhotosPicker directly (no intermediate dialog)
- Profile image persisted as base64 in @AppStorage("riffit_profile_image")
- Camera badge overlay (18×18 gold circle with camera icon)
- Editable full name and username fields (persisted to @AppStorage)
- Username has @ prefix, autocap off, autocorrect off
- Pencil icon when unfocused, "Done" button when focused
- Identity card reactively updates from field values
- Workspace section: 3 "Coming soon" placeholder rows
- Danger section: "Delete account" with confirmation alert (no-op)

#### InfluencesView
- Computes everything from StorybankViewModel.storyReferencesMap + LibraryViewModel.videos
- Summary strip: References count, Unique videos, Used 3+×
- "Most Referenced" — top 6 videos with platform-colored dots and count badges
- "What You Reference" — tag breakdown with animated progress bars (per-tag colors)
- "Pattern Spotted" — teal tint insight card when dominant tag ≥30%
- Dynamic subtitle on Settings row: "X videos referenced 3+ times"

---

## Architecture Changes

### ViewModel Sharing
- `StorybankViewModel` lifted from `StorybankView` (local @StateObject) to `MainTabView` (shared @StateObject + .environmentObject)
- Both `LibraryViewModel` and `StorybankViewModel` are now available app-wide via @EnvironmentObject
- `SettingsView` and `InfluencesView` access both for computed analytics

### New Service Layer
```
Core/Audio/
  AudioRecorderService.swift    — AVAudioRecorder wrapper
  AudioPlayerService.swift      — AVAudioPlayer wrapper

Core/Media/
  ImageStorageService.swift     — JPEG save/load/delete
  VideoStorageService.swift     — Video copy/thumbnail/duration
  CameraPickerView.swift        — Camera + PhotoLibrary pickers (images)
  VideoPickerView.swift         — Camera + PhotoLibrary pickers (videos)
  AssetExportService.swift      — Export to Camera Roll / share text

Components/
  FlowLayout.swift              — Wrapping horizontal layout (for tags)
  ShareSheet.swift              — UIActivityViewController wrapper
```

### Info.plist Keys Added
- `NSMicrophoneUsageDescription` — voice note recording
- `NSCameraUsageDescription` — photo/video capture
- `NSPhotoLibraryUsageDescription` — photo/video selection
- `NSPhotoLibraryAddUsageDescription` — saving to Camera Roll

---

## Models (Current State)

```
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
```

---

## File Structure (Current)

```
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
├── Components/
│   ├── AlignmentBadge.swift
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
```

---

## What Still Doesn't Exist

- No Supabase connection (all data in-memory, profile data in @AppStorage)
- No test target, no test files, no CI configuration
- No persistence — app data resets on relaunch
- No onboarding flow (skipped for MVP)
- No RevenueCat / subscription logic
- No share extension functionality (file exists but is scaffolding)
- No AI features (all dormant in EdgeFunctions.swift)
- CreatorProfile, User, VideoDeconstruction models exist but aren't used in any views

---

## Patterns Established

### Prompting
- One bug / one feature per prompt
- Start every session: Read CLAUDE.md + Read CONTEXT files + Read specific files
- Describe what and why, let Claude figure out how
- Be explicit about design tokens and architecture constraints

### Code Patterns
- All ViewModels are @MainActor ObservableObject
- Colors via RiffitColors tokens only
- Fonts via RiffitTheme (RF/RS/RR typealiases)
- New files must be added to project.pbxproj (PBXFileReference + PBXBuildFile + PBXGroup + Sources build phase)
- Local media storage: Documents/{voice_notes,images,videos}/ with UUID filenames for Supabase readiness
- Profile data: @AppStorage with "riffit_" prefix keys
- Modals: centered overlay with dim background (RiffitInputModal, RiffitConfirmModal, RiffitActionModal)
- Sheet backgrounds: .presentationBackground(Color.riffitBackground) to avoid gray sides
