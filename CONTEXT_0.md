# Riffit — Session Context
# Summary of all decisions, bugs fixed, and features built
# Reference this alongside CLAUDE.md

---

## Product Decisions

- MVP is solo creator tool (Tim), with future team/agency plans
- Platforms: Instagram, TikTok, YouTube, LinkedIn, X
- Monetization: Freemium + Pro subscription
- Output: Creative brief / shot list (not video assembly — that's v2 Pro)
- Briefs tab removed entirely — brief generation is v2 Pro feature inside Stories
- Onboarding skipped for MVP
- AI features removed from v1 entirely (see Removed Features)

---

## Features Built

### Library
- Scrollable InspirationCard feed
- Tag filter bar (All, Hook, Editing, B-Roll, Format, Topic, Inspiration)
- Folder support with long-press context menu
- + button opens centered modal (New Idea / New Folder)
- New Idea from folder pre-fills folder_id
- CaptureSheet: URL + manual title + Your take note + tag pills
- VideoDetailView: editable title, editable tags, comment thread notes
- Share extension from Instagram/other apps

### Storybank
- StoryCard list with asset + reference counts
- New Story: multi-step sheet (title → bulk asset upload → skip/create)
- StoryDetailView: MY ASSETS + REFERENCES sections
- Asset types: Text, Voice, Video, Image with type-specific icons
- Asset name field (editable label per asset)
- Drag to reorder assets (.onMove)
- Tap text asset to edit (full screen editor with name + body)
- Add from Library: two-step picker (pick idea → pick reference tag)
- Reference card shows real video title + Your take note

### Empty States
- Library light: wave barrel illustration, "Nothing here yet"
- Library dark: same, inverted teal palette
- Storybank light: sunset beach scene, "Your story starts here"
- Storybank dark: campfire night scene, "Every story needs a spark"
- No stripe bars on empty states

### Auth
- Apple Sign In
- #if DEBUG test user bypass

---

## Design Decisions

### Brand
- Tagline: scroll, riff, post
- Mood: dark creative studio meets 70s surf culture
- Copy: catch, reel, ride, drop, wave, riff, spark
- Inspiration image: wave barrel at sunset photo

### Colors
- Primary accent: #F0AA20 (sunset gold)
- Secondary: #0F6B75 teal family (900/600/400)
- Danger: #D94E2A (coral burn — errors only)
- Dark bg: #111111, surface #1C1C1C
- Light bg: #F5F2EB beige, grid bg #F0EBD8

### Typography
- Headings/buttons: Lora Bold (chosen over Abril Fatface — too fatiguing at UI scale)
- Body/metadata: DM Sans Regular/Light
- Wordmark only: Georgia Bold Italic (never in UI)
- Fonts centralized in RiffitTheme.swift — change one line = whole app updates

### Logo
- Wordmark: Georgia Bold Italic, 7-layer bubbly stroke system
  Layers: deep teal shadow → coral shadow → dark teal → mid teal → light teal → amber ring → gold fill
- App icon: V3 Max Bubble R — black bg, gold border, same 7-layer R
- Rejected: orange (too close to Claude brand), plain letter R, wave illustrations

### Navigation
- 3 tabs: Library / Storybank / Settings
- Modals: centered overlay with dim background (not bottom sheets)
- Never use UIAlertController or .actionSheet

### Empty State Copy Rules
- Library: "Nothing here yet" / "Catch a reel. Drop it here."
- Storybank light: "Your story starts here"
- Storybank dark: "Every story needs a spark"
- Button copy: verb first — "Drop your first reel" / "Start a new story"

---

## Bugs Fixed (in order)

1. Dark mode background hardcoded to beige — fixed with colorScheme environment
2. Stars flanking "Nothing here yet" headline removed (hard to read)
3. "Pick a Video" renamed to "Pick an Idea"
4. Add from Library empty — fetchVideos() not called on appear, fixed with .onAppear
5. Reference card showing "Linked inspiration" placeholder — now shows real video title
6. Debug red borders left in views — removed
7. ff ligature artifacts in wordmark — zero-width non-joiner added
8. Auth screen logo small with debug borders — fixed sizing + removed borders
9. Font change took forever — caused by no centralized typography system
   Fix: RiffitTheme.swift as single source of truth
10. Auto-fetch video metadata broke app (too slow) — removed entirely
11. Stats auto-pull not working — stats fields removed from UI entirely

---

## Removed Features (Do Not Re-Add Without Being Asked)

- AI alignment scoring (score, verdict, badge, "Waiting to analyze")
- AI brief generation
- AI onboarding interview
- AI relevance notes on references  
- Auto-generated video summaries
- Auto-fetch video metadata on URL paste
- Video stats (views/likes/comments) — fields in DB but not in UI
- Stats display on cards
- AlignmentBadge component
- Shimmer/skeleton loading states
- Briefs tab

---

## Architecture Decisions

- Supabase backend (Postgres + Auth + Edge Functions)
- All AI calls through Edge Functions only — dormant in v1
- Business logic in Edge Functions, never in Swift views
- RLS on every table
- iOS share sheet for URL capture
- External drive access via iOS Files app (v2)
- pgvector for storybank semantic search (v2)
- RevenueCat for subscriptions (v2)

---

## Active Edge Functions

- fetch-video-metadata: gets og:title, og:image from URL — ACTIVE

## Dormant Edge Functions (v1 — do not call)

- analyze-video
- score-alignment  
- generate-brief
- run-interview
- transcribe-audio

---

## V2 Features (not in MVP)

- AI brief generation (Pro feature inside Stories)
- Asset library connected to external drive / iCloud
- AI relevance notes on references
- Video stats auto-pull via Phyllo API
- Team workspace / shared brand profiles
- Rough cut video assembly
- AI voiceover + b-roll generation
- Content calendar
- Agency/multi-brand plan
- React web app (backend already designed for it)

---

## Session Rules That Worked

- One bug / one feature per Claude Code prompt
- Commit after every clean build
- Fresh Claude Code session when context degrades
- Start every session: Read CLAUDE.md + Read CONTEXT.md + Read [specific file]
- Ask Claude Code to describe current state before writing any fix
