# Riffit — Progress Report

> Full project audit — read-only, no code changes made.
> Generated: 2026-03-18

---

## Executive Summary

The iOS frontend is ~95% complete for MVP scope. Every screen is built,
interactive, and follows the design system consistently. Zero force
unwraps across 60 Swift files. The backend is 0% complete — all data
lives in memory and resets on app relaunch. The project has no tests,
no CI, and no Supabase connection. The next phase is persistence.

---

## Screens

### LibraryView (Ideas tab)
**Status:** Complete UI, no persistence
- Scrollable idea feed with InspirationCard components
- Folder support with drag-to-organize (FolderDropTarget)
- Pull-to-refresh (calls stubbed fetchVideos)
- Empty state: wave barrel illustration with grid background (Canvas-drawn)
- `+` button opens action modal (New Idea / New Folder)
- NavigationLink to InspirationDetailView and FolderDetailView
- **Issue:** fetchVideos() is a no-op — returns immediately with no data

### InspirationDetailView (Idea detail)
**Status:** Complete UI, no persistence
- Editable title field (saves to in-memory viewModel)
- Embedded WKWebView for video playback
- Interactive tag section with FlowLayout wrapping, create/delete custom tags
- Expandable transcript section (if transcript exists — currently never populated)
- Notes thread with avatar, display name, inline editing, timestamps
- Comment input bar pinned at bottom
- **Issue:** Transcript section will never show until Supabase transcription is wired

### AddInspirationView (Capture sheet)
**Status:** Complete UI, no persistence
- URL field (validates Instagram URLs only — instagram.com or instagr.am)
- Manual title field, "Your take" note field
- Tag selector (defaults + custom, long-press to delete)
- Folder picker (Menu dropdown, full-width)
- **Issue:** Only validates Instagram URLs — other platforms (TikTok, YouTube, etc.) will fail validation

### FolderDetailView
**Status:** Complete UI, no persistence
- Shows ideas in folder, rename/delete folder via toolbar menu
- Context menu to remove idea from folder
- Draggable idea rows

### StorybankView (Storybank tab)
**Status:** Complete UI, no persistence
- Story list with StoryCard components (title, counts, status badge, timestamp)
- Folder support with drag-to-organize
- Empty state: SunsetBeachScene (light) / CampfireNightScene (dark) — elaborate Canvas illustrations
- `+` button opens action modal (New Story / New Folder)
- NavigationLink to StoryDetailView and StoryFolderDetailView

### StoryDetailView
**Status:** Complete UI, no persistence
- **MY ASSETS section:** Flat list with interleaved section headers, cross-section drag reorder
- Asset types: text (inline editor), voice note (record + play), image (camera/library + view), video (record/library + play)
- Asset rows show thumbnails for images/videos, duration for voice/video
- Section CRUD (add/rename/delete via modals)
- **REFERENCES section:** Links to Library ideas, shows section pill + idea tags, long-press to delete, drag to reorder
- **NOTES section:** Avatar + display name, inline editing, timestamps, add input
- **Export:** Single asset via context menu, all assets via toolbar menu
- Toolbar: rename story, archive, save all assets, delete story

### SettingsView
**Status:** Complete UI, mostly placeholders
- Account card (reactive avatar + display name) → NavigationLink to AccountView
- Plan section: "Riff Pro" + "Current usage" → placeholder destinations
- Creative section: "Creator profile" → placeholder, "Your influences" → InfluencesView (functional)
- App section: Appearance → AppearanceSettingsView (functional, persists to UserDefaults)
- Legal section: Privacy policy, Terms of service → placeholders, Version from bundle
- Sign out button with confirmation alert (no-op action)

### AccountView
**Status:** Complete UI, @AppStorage persistence only
- Interactive avatar: tap opens PhotosPicker directly, image stored as base64 in @AppStorage
- Camera badge overlay on avatar
- Editable full name and username fields (persisted to @AppStorage)
- Display name logic: @username if set, else full name
- Workspace section: 3 "Coming soon" placeholder rows
- Danger section: Delete account with confirmation alert (no-op)

### InfluencesView
**Status:** Complete, computed from in-memory data
- Summary strip: total references, unique videos, used 3+ times
- Most Referenced: top 6 videos with platform dots, count badges
- What You Reference: tag breakdown with animated progress bars
- Pattern Spotted: teal insight card when dominant tag ≥30%
- All computed from StorybankViewModel.storyReferencesMap — will work correctly once data persists

### AuthView
**Status:** Complete UI, stubbed backend
- Riffit wordmark + tagline
- Sign in with Apple button (ASAuthorizationAppleIDButton)
- `#if DEBUG` test user bypass (good practice)
- Error banner overlay
- **Issue:** Auth flow creates a placeholder UUID instead of calling Supabase Auth

### OnboardingView (3 steps)
**Status:** Complete UI, fully stubbed backend
- Step 1: CreatorTypeView — 5 type options, well-designed cards
- Step 2: InterviewView — chat UI with typing indicator, input bar — all AI responses are hardcoded placeholders
- Step 3: SocialConnectView — 5 platform inputs, optional skip
- **Issue:** Entire flow is theater — no data is saved, no AI is called

---

## Components

| Component | Status | Issues |
|---|---|---|
| InspirationCard | Complete | Uses `.frame(maxWidth: .infinity)` fix for full width |
| AlignmentBadge | Complete but unused | Was for AI alignment — kept in codebase, never rendered |
| RiffitButton | Complete | 4 variants: primary, secondary, ghost, danger |
| RiffitWordmark | Complete | 7-layer stroke system, hardcoded UIColors (appropriate for Canvas) |
| FlowLayout | Complete | Custom SwiftUI Layout for wrapping tag pills |
| ShareSheet | Complete | UIActivityViewController wrapper |
| LoadingOverlay | Complete | Not currently used anywhere |
| TagPill | Complete | Defined inside AddInspirationView |

---

## Models

| Model | Properties Match CLAUDE.md | Used In Views | Persistence |
|---|---|---|---|
| InspirationVideo | Partial — removed stats fields, simplified status | Yes | None |
| IdeaComment | Yes (added mutable text) | Yes | In-memory |
| IdeaFolder | Yes | Yes | In-memory |
| Story | Yes | Yes | In-memory |
| StoryAsset | Extended — added sectionId | Yes | In-memory |
| StoryReference | Extended — added displayOrder | Yes | In-memory |
| StoryNote | New (not in CLAUDE.md) | Yes | In-memory |
| StoryFolder | New (not in CLAUDE.md) | Yes | In-memory |
| AssetSection | New (not in CLAUDE.md) | Yes | In-memory |
| User | Matches CLAUDE.md | **Not used** | None |
| CreatorProfile | Matches CLAUDE.md | **Not used** | None |
| VideoDeconstruction | Matches CLAUDE.md | **Not used** | None |

**Note:** User, CreatorProfile, and VideoDeconstruction are complete model definitions
that exist for future Supabase integration but have zero usage in any view or viewmodel.

---

## ViewModels

### LibraryViewModel
- **Implemented:** Video list, folder CRUD, tag management (availableTags, toggle, create, delete), comments CRUD, video title updates, fetchVideoMetadata (calls EdgeFunction which fatalErrors)
- **Stubbed:** fetchVideos() (no-op), all Supabase save/update calls
- **Data:** 7 @Published dictionaries, all in-memory

### StorybankViewModel
- **Implemented:** Story CRUD, asset CRUD (all 4 types with name), section CRUD, reference CRUD, note CRUD, folder CRUD, flat row computation for sections, asset reordering, reference reordering
- **Stubbed:** fetchStories() (no-op), all Supabase save/update calls, creator profile ID (hardcoded UUID())
- **Data:** 6 @Published dictionaries + folders array, all in-memory

### AuthViewModel
- **Implemented:** Apple Sign In credential extraction, nonce generation, SHA256 hashing
- **Stubbed:** Supabase token exchange, user record fetch, onboarding status check
- **Current behavior:** Creates placeholder UUID, sets isAuthenticated = true

### OnboardingViewModel
- **Implemented:** Step navigation, creator type selection, conversation history tracking
- **Stubbed:** All AI interview calls (returns hardcoded follow-up questions), session creation, profile extraction
- **Current behavior:** Simulates a 3-message interview then completes

### AppState
- **Implemented:** Auth state, onboarding state, appearance mode with UserDefaults persistence
- **Complete** — no stubs

---

## Navigation

### 3-Tab Structure: Correct
- Tab 1: Library (lightbulb icon) → LibraryView
- Tab 2: Storybank (bookmark icon) → StorybankView
- Tab 3: Settings (gearshape icon) → SettingsView

### Navigation Flows (all working)
- Library → InspirationDetailView (via NavigationLink)
- Library → FolderDetailView (via NavigationLink)
- Storybank → StoryDetailView (via NavigationLink)
- Storybank → StoryFolderDetailView (via NavigationLink)
- StoryDetailView → InspirationDetailView (via sheet, for reference tap)
- Settings → AccountView (via NavigationLink)
- Settings → InfluencesView (via NavigationLink)
- Settings → AppearanceSettingsView (via NavigationLink)

### Shared ViewModels
- LibraryViewModel: created in MainTabView, shared via @EnvironmentObject
- StorybankViewModel: created in MainTabView, shared via @EnvironmentObject
- AppState: created in RiffitApp, shared via @EnvironmentObject

---

## Design System Compliance

### Colors
- **RiffitColors tokens used consistently** across all feature views
- **Acceptable hardcoded colors (by design):**
  - RiffitWordmark.swift — Canvas stroke layers (UIColor, can't use SwiftUI Color)
  - StorybankView.swift — Canvas illustrations (scene-specific colors: navy sky, sand, tree bark, fire)
  - InfluencesView.swift — Platform dots (YouTube red, TikTok cyan, etc.) and tag bar colors (per spec)
- **Should be tokenized:**
  - ShareViewController.swift line 20: `UIColor(red: 0.941, green: 0.667, blue: 0.125, alpha: 1.0)` — gold nav bar color

### Typography
- All views use RF typealiases (RF.heading, RF.bodyMd, RF.caption, etc.)
- A few places use `.custom("DMSans-Medium", size: N)` or `.custom("Lora-Bold", size: N)` directly — acceptable for specific sizes not in the scale (avatar initials, account name)

### Spacing
- All views use RS typealiases (RS.md, RS.smPlus, RS.lg, etc.)
- No raw number padding/spacing found outside of Canvas illustrations

### Force Unwraps
- **Zero instances** across all 60 files — excellent

---

## All TODOs Found (28 total)

### Backend/Persistence (20) — blocking
1. `SupabaseClient.swift:11` — Initialize Supabase SDK
2. `EdgeFunctions.swift:73` — analyze-video
3. `EdgeFunctions.swift:79` — score-alignment
4. `EdgeFunctions.swift:85` — generate-brief
5. `EdgeFunctions.swift:91` — run-interview
6. `EdgeFunctions.swift:97` — transcribe-audio
7. `EdgeFunctions.swift:104` — fetch-video-metadata
8. `AuthViewModel.swift:76` — Send token to Supabase Auth
9. `AuthViewModel.swift:87` — Fetch user record
10. `OnboardingViewModel.swift:54` — Create OnboardingSession in Supabase
11. `OnboardingViewModel.swift:71` — Call run-interview (opening)
12. `OnboardingViewModel.swift:103` — Call run-interview (user message)
13. `OnboardingViewModel.swift:140` — Return real creator profile ID
14. `LibraryViewModel.swift:54` — Update tags in Supabase
15. `LibraryViewModel.swift:111` — Fetch from Supabase
16. `LibraryViewModel.swift:128` — Save to Supabase
17. `LibraryViewModel.swift:171` — Update title in Supabase
18. `StorybankViewModel.swift:117` — Fetch from Supabase
19. `StorybankViewModel.swift:218` — Update asset in Supabase
20. `StorybankViewModel.swift:248` — Batch update display_order in Supabase

### Auth/Account (3) — blocking for production
21. `SettingsView.swift:208` — Wire sign out to auth
22. `AccountView.swift:159` — Wire account deletion
23. `StorybankViewModel.swift:126` — Use real creator profile ID

### Other (5) — non-blocking
24. `SocialConnectView.swift:60` — Save social accounts to Supabase
25. `ShareViewController.swift:35` — Save via app group or background upload
26. `AudioPlayerService` comment — Swap to stream from Supabase Storage URLs
27. `LoadingOverlay.swift` — Exists but unused
28. `AlignmentBadge.swift` — Exists but unused (AI feature removed)

---

## Not Yet Started (from CLAUDE.md)

| Feature | Priority | Dependency |
|---|---|---|
| Supabase project + schema | **Critical** | None |
| Supabase Auth integration | **Critical** | Supabase project |
| Data persistence (fetch/save) | **Critical** | Supabase project |
| Row Level Security policies | **Critical** | Supabase schema |
| Supabase Storage (media upload) | High | Supabase project |
| Edge Function deployment | High | Supabase project |
| RevenueCat integration | Medium | App Store account |
| Share extension backend | Medium | Supabase + app group |
| Test target + unit tests | Medium | None |
| CI configuration | Low | Test target |
| pgvector semantic search | Low (v2) | Supabase + AI |

---

## Ready for Supabase (screens stable enough to wire)

### Tier 1 — Wire first (core data flow)
1. **LibraryViewModel** — fetchVideos, addVideo, updateTitle, tags
2. **StorybankViewModel** — fetchStories, createStory, addAsset, addReference
3. **AuthViewModel** — token exchange, user record fetch

### Tier 2 — Wire second (media + persistence)
4. **Media upload** — voice notes, images, videos to Supabase Storage
5. **Asset export** — already works locally, just needs remote URLs
6. **Notes/comments** — simple append-only tables

### Tier 3 — Wire last (features that need AI or complex logic)
7. **Onboarding interview** — needs run-interview Edge Function
8. **Video transcription** — needs transcribe-audio Edge Function
9. **Share extension** — needs app group + background upload pattern

---

## Unused Files (safe to delete or keep for future)

| File | Reason | Recommendation |
|---|---|---|
| AlignmentBadge.swift | AI feature removed | Delete — will cause confusion |
| LoadingOverlay.swift | Never referenced | Keep — will be useful for Supabase loading states |
| VideoDeconstruction.swift | AI feature, no views | Keep — needed when AI is re-enabled |
| CreatorProfile.swift | No views use it | Keep — needed for onboarding + AI |
| User.swift | No views use it | Keep — needed for auth |
