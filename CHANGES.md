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
