# Riffit — CONTEXT_LATEST

> **This is the only context file Claude Code needs to read.**
> Read this alongside CLAUDE.md before every session.
> Previous context files are archived in `/docs/history/` for reference only.
>
> Last updated: 2026-03-18

---

## How This File Works

This file is the rolling source of truth for what has been built, what
decisions have been made, and what the current state of the codebase is.
It replaces the numbered CONTEXT_0.md, CONTEXT_1.md pattern.

**When to update this file:**
At the end of each session, append a new entry to the Session Log at
the bottom using the template below. If a session changes something
fundamental (new model, architecture shift, removed feature), also
update the relevant section above the log.

**When to archive:**
If this file exceeds ~400 lines, move everything except the last 3
session log entries and the current-state sections to
`/docs/history/CONTEXT_N.md` (incrementing N). Then trim this file
back to current state + recent log.

---

## Append Template

When adding a session entry, copy this block and fill it in:

```markdown
### YYYY-MM-DD — [short description]

**What changed:**
- [bullet per feature/fix, include file names]

**Decisions made:**
- [any new "do not re-add" items or architecture choices]

**Files created:**
- [list new files only, not modified ones]

**Files modified:**
- [list modified files only]

**Build status:** Zero errors confirmed
```

---

## Current Product State

MVP v1 — solo creator tool, no AI, no persistence, no Supabase connection.
All data is in-memory (resets on app relaunch). Profile data only persists
via @AppStorage.

### What Works
- Save ideas (URL + title + note + tags + folder)
- Browse, edit, tag, and organize ideas in folders
- Create stories with text, voice, image, and video assets
- Organize assets into named sections with drag reorder
- Add idea references to stories (linked to sections)
- Record voice notes (press-and-hold), take/pick photos, record/pick videos
- Play back voice notes, view images, play videos from asset rows
- Export assets to Camera Roll or share as files
- Notes threads on both ideas and stories (with avatar + inline editing)
- Folder organization in both Library and Storybank
- Settings with account management, appearance, influences analytics
- Profile photo upload, editable name/username

### What Doesn't Work Yet
- No Supabase connection — all data in-memory
- No persistence — app data resets on relaunch
- No onboarding flow
- No RevenueCat / subscription logic
- No share extension (file exists but is scaffolding)
- No AI features (all dormant in EdgeFunctions.swift)
- No tests, no CI
- CreatorProfile, User, VideoDeconstruction models exist but aren't used

---

## Decisions That Stick (Do Not Re-Add Without Being Asked)

### Removed Features
- AI alignment scoring (score, verdict, badge, shimmer states)
- AI brief generation, onboarding interview, relevance notes
- Auto-generated video summaries
- Auto-fetch video metadata on URL paste
- Video stats (views/likes/comments) — fields in Supabase, not in Swift
- AlignmentBadge component, ShimmerBlock component
- Briefs tab
- StatField component

### Architecture Decisions
- References use the story's actual sections, not a hardcoded 6-tag picker
- Folder picker uses Menu (not Picker or modal) — never use invisible overlay hacks
- Tags are user-manageable (create/delete any tag, including defaults)
- `availableTags` on LibraryViewModel replaces static `IdeaTag.defaults`
- StorybankViewModel is shared via @EnvironmentObject from MainTabView (not local to StorybankView)
- Asset sections use flat list approach (interleaved ForEach, not multiple SwiftUI Sections)
- Section headers are draggable (`.moveDisabled(true)` creates barriers — don't use it)
- Media files stored in Documents/{voice_notes,images,videos}/ with UUID names for Supabase readiness
- Profile data uses @AppStorage with "riffit_" prefix keys
- Sheet backgrounds: always use `.presentationBackground(Color.riffitBackground)`
- Modals: centered overlay with dim background (never UIAlertController or .actionSheet)

---

## Models (Current)

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

## Info.plist Keys

- `NSMicrophoneUsageDescription` — voice note recording
- `NSCameraUsageDescription` — photo/video capture
- `NSPhotoLibraryUsageDescription` — photo/video selection
- `NSPhotoLibraryAddUsageDescription` — saving to Camera Roll
- `UIAppFonts` — Lora (Regular/Medium/Bold/Italic), DM Sans (Light/Regular/Medium)

---

## Session Rules

- One bug / one feature per prompt
- Commit after every clean build
- Fresh Claude Code session when context degrades
- Start every session: `Read CLAUDE.md and CONTEXT_LATEST.md fully before writing any code.`
- Ask Claude Code to describe current state before writing any fix
- Describe what and why, let Claude figure out how
- Be explicit about design tokens and architecture constraints
- New files must be added to project.pbxproj (4 entries: PBXFileReference + PBXBuildFile + PBXGroup + Sources)

---

## Session Log

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
- Context files consolidated: CONTEXT_LATEST.md replaces CONTEXT_0 + CONTEXT_1

**Files created:**
- InfluencesView.swift, CONTEXT_LATEST.md

**Files modified:**
- MainTabView.swift, StorybankView.swift, SettingsView.swift
- InspirationDetailView.swift, StoryDetailView.swift
- LibraryViewModel.swift, StorybankViewModel.swift, AccountView.swift

**Build status:** Zero errors confirmed
