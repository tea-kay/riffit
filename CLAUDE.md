# Riffit — Claude Code Project Memory

> Read this entire file at the start of every session before writing any code.
> This is the source of truth for every decision in this project.

---

## What Riffit Is

Riffit is an AI-powered content intelligence and creative planning tool for video creators. The core loop:

1. Creator finds an inspiring video on Instagram, TikTok, YouTube, LinkedIn, or X
2. Shares the URL into Riffit with a short note
3. Riffit transcribes the video, scores its alignment to the creator's brand, and deconstructs it into components (hook, structure, b-roll moments, pacing, cuts)
4. Riffit remixes the concept into a creative brief written in the creator's voice, referencing their personal stories from their Storybank
5. Creator walks away with a shot list ready to film

The app replaces a messy Apple Notes + spreadsheet workflow with an intelligent creative assistant that knows the creator deeply.

**App name:** Riffit  
**Bundle ID:** com.riffit.app  
**Primary platform:** iOS (SwiftUI), with backend designed for future React web client  
**Current phase:** MVP v1

---

## Developer Context

The developer is new to Swift and iOS. This means:
- Always use SwiftUI (never UIKit) unless there is no SwiftUI equivalent
- Prefer simple, readable code over clever code
- Add comments explaining *why*, not just what
- Break complex views into small named subviews
- Never use force unwraps (`!`) — always use `if let`, `guard let`, or optional chaining
- Prefer `async/await` over completion handlers
- When introducing a new Swift concept or pattern, add a brief comment explaining it
- Favor explicit types over inferred types when it aids readability

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| iOS UI | SwiftUI | Native iOS, follows Apple HIG |
| Backend | Supabase | Postgres + Auth + Storage + Edge Functions |
| AI | Anthropic Claude API | All AI calls go through Edge Functions only |
| Transcription | AssemblyAI | Called from Edge Functions, never from client |
| Subscriptions | RevenueCat | Wraps StoreKit, handles entitlements |
| Vector search | pgvector (Supabase plugin) | Semantic search on StoryBank |
| Analytics | PostHog | Product analytics |
| Edge Functions | Deno / TypeScript | Business logic lives here, not in Swift |

**Critical rule:** API keys (Claude, AssemblyAI, etc.) are NEVER in the Swift codebase. They live as environment variables in Supabase Edge Functions only.

---

## Architecture

```
iOS App (SwiftUI)          Web App (React, future)
      |                              |
      | Supabase Swift SDK           | Supabase JS SDK
      |                              |
      └──────────── Supabase ────────┘
                        |
              ┌─────────┴─────────┐
              │                   │
         Supabase Auth      Edge Functions (Deno/TS)
         (JWT, Apple         - analyze-video
          Sign In)           - score-alignment
              │              - generate-brief
              │              - run-interview
              │              - transcribe-audio
         Supabase Postgres
         + pgvector
         + Row Level Security
              │
         Supabase Storage
         (voice notes,
          thumbnails)
              │
         External Services
         (called ONLY from Edge Functions)
         - Claude API
         - AssemblyAI
         - RevenueCat webhooks
         - PostHog
```

**All business logic lives in Edge Functions.** The Swift app is a thin client — it handles UI, navigation, and user interaction only. It calls Edge Functions and renders results. This ensures the future React web client can call the same endpoints with zero logic duplication.

---

## Data Model

### User
```sql
id              uuid PRIMARY KEY
email           text
full_name       text
avatar_url      text (nullable)
subscription_tier  text CHECK (IN ('free', 'pro')) DEFAULT 'free'
onboarding_complete  boolean DEFAULT false
created_at      timestamptz DEFAULT now()
```

### CreatorProfile
The brand brain. Everything the AI knows about the creator.
```sql
id                    uuid PRIMARY KEY
user_id               uuid REFERENCES users(id)
creator_type          text CHECK (IN ('personal_brand', 'educator', 'entertainer', 'business', 'agency'))
niche                 text
mission_statement     text
target_audience       text
content_pillars       text[]
tone_markers          text[]        -- e.g. ["conversational", "vulnerable", "direct"]
never_do              text[]        -- e.g. ["swear", "sell too hard", "political content"]
hot_takes             text[]
interview_transcript  jsonb         -- full AI interview conversation history
created_at            timestamptz DEFAULT now()
updated_at            timestamptz DEFAULT now()
```

### OnboardingSession
Resumable — user can drop off and pick up without losing progress.
```sql
id                      uuid PRIMARY KEY
user_id                 uuid REFERENCES users(id)
creator_type_selected   text (nullable)
current_step            int DEFAULT 0
conversation_history    jsonb DEFAULT '[]'  -- array of {role, content} messages
completed_at            timestamptz (nullable)
created_at              timestamptz DEFAULT now()
```

### Story
The creative workspace. Each story organizes assets and references to inspiration videos.
```sql
id                  uuid PRIMARY KEY
creator_profile_id  uuid REFERENCES creator_profiles(id)
title               text
status              text CHECK (IN ('draft', 'ready', 'archived')) DEFAULT 'draft'
created_at          timestamptz DEFAULT now()
updated_at          timestamptz DEFAULT now()
```

### StoryAsset
Media and text attached to a Story (voice notes, video, images, text blocks).
```sql
id                  uuid PRIMARY KEY
story_id            uuid REFERENCES stories(id)
asset_type          text CHECK (IN ('voice_note', 'video', 'image', 'text'))
content_text        text (nullable)          -- for text assets
file_url            text (nullable)          -- for voice/video/image assets
duration_seconds    int (nullable)           -- for voice/video assets
display_order       int
created_at          timestamptz DEFAULT now()
```

### StoryReference
Links a Story to an InspirationVideo from the Library.
```sql
id                      uuid PRIMARY KEY
story_id                uuid REFERENCES stories(id)
inspiration_video_id    uuid REFERENCES inspiration_videos(id)
reference_tag           text    -- Hook, Editing, B-Roll, Format, Topic, Inspiration
ai_relevance_note       text (nullable)  -- AI-generated explanation of relevance
created_at              timestamptz DEFAULT now()
```

### InspirationVideo
A saved video from any platform.
```sql
id                    uuid PRIMARY KEY
creator_profile_id    uuid REFERENCES creator_profiles(id)
url                   text
platform              text CHECK (IN ('instagram', 'tiktok', 'youtube', 'linkedin', 'x'))
user_note             text (nullable)
thumbnail_url         text (nullable)
transcript            text (nullable)
alignment_score       int (nullable)          -- 0 to 100
alignment_verdict     text CHECK (IN ('skip', 'consider', 'strong')) (nullable)
alignment_reasoning   text (nullable)
status                text CHECK (IN ('pending', 'analyzing', 'analyzed', 'archived')) DEFAULT 'pending'
saved_at              timestamptz DEFAULT now()
```

### VideoDeconstruction
One-to-one with InspirationVideo. Created after analysis.
```sql
id                    uuid PRIMARY KEY
inspiration_video_id  uuid REFERENCES inspiration_videos(id) UNIQUE
hook_text             text
hook_type             text CHECK (IN ('question', 'stat', 'story', 'bold_claim', 'visual'))
full_transcript       text
structure_segments    jsonb[]   -- [{type, text, timing_start, timing_end}]
broll_moments         jsonb[]   -- [{description, timing, duration}]
transition_notes      text (nullable)
cut_count             int
pacing                text CHECK (IN ('slow', 'medium', 'fast'))
created_at            timestamptz DEFAULT now()
```

### SocialAccount
Connected social platforms for brand context.
```sql
id                  uuid PRIMARY KEY
user_id             uuid REFERENCES users(id)
platform            text CHECK (IN ('instagram', 'tiktok', 'youtube', 'linkedin', 'x'))
handle              text
follower_count      int (nullable)
avg_views           int (nullable)
top_performing_tags text[] (nullable)
connected_at        timestamptz DEFAULT now()
```

### Row Level Security
Every table has RLS enabled. Users can only read and write their own data.
Pattern for every table:
```sql
ALTER TABLE [table] ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users can only access own data" ON [table]
  FOR ALL USING (
    auth.uid() = user_id  -- or join path back to user_id
  );
```

---

## Design System

### Color Tokens

#### Dark Mode
```
Background:        #111111   -- screen background
Surface:           #1C1C1C   -- cards, sheets, rows
Elevated:          #272727   -- modals, popovers, dropdowns
Border subtle:     rgba(255,255,255, 0.07)
Border default:    rgba(255,255,255, 0.10)

Text primary:      #F2F0EB   -- titles, headings
Text secondary:    #888888   -- body, descriptions
Text tertiary:     #444444   -- timestamps, metadata

Primary:           #F0AA20   -- sunset gold — buttons, active states, scores
Primary pressed:   #E87820   -- amber — pressed/active
Primary tint:      rgba(240,170,32, 0.12)  -- badge backgrounds
Primary ghost:     rgba(240,170,32, 0.06)  -- hover, selected rows

Teal 900:          #0A4A52   -- darkest, structural
Teal 600:          #0F6B75   -- secondary actions, info
Teal 400:          #1A8A96   -- links, interactive hints
Teal tint:         rgba(15,107,117, 0.15)  -- storybank badges

Danger:            #D94E2A   -- coral burn — errors, skip, destructive only
Danger tint:       rgba(217,78,42, 0.12)
```

#### Light Mode
```
Background:        #F5F2EB   -- warm off-white beige
Surface:           #FFFFFF   -- cards (white on beige)
Elevated:          #FFFFFF   -- modals with shadow
Border subtle:     rgba(0,0,0, 0.06)
Border default:    rgba(0,0,0, 0.10)

Text primary:      #1A1A1A
Text secondary:    #888888
Text tertiary:     #AAAAAA

Primary:           #F0AA20   -- same fill on buttons
Primary text:      #C88A00   -- darker gold for text/labels on light bg (a11y)
Primary tint:      rgba(200,138,0, 0.10)

Teal 600:          #0F6B75   -- same, sufficient contrast on light
Teal tint:         rgba(15,107,117, 0.08)

Danger:            #C03D1E   -- slightly darker for light mode legibility
Danger tint:       rgba(217,78,42, 0.08)
```

#### Mode behavior
Follows iOS system setting. Use SwiftUI's `@Environment(\.colorScheme)` to switch.
Create a `RiffitColors` environment object that exposes the correct token set based on colorScheme.
Never hardcode hex values in views — always reference tokens via `RiffitColors`.

### Typography
All using SF Pro (iOS system font — no import needed).

```
Display:    .largeTitle   32pt   weight: .medium
Title:      .title        22pt   weight: .medium
Heading:    .headline     17pt   weight: .medium  (system default for .headline)
Body:       .body         17pt   weight: .regular
Callout:    .callout      16pt   weight: .regular
Subhead:    .subheadline  15pt   weight: .regular
Caption:    .caption      12pt   weight: .regular
Label:      .caption2     11pt   weight: .medium  + tracking 0.06em + uppercase
```

### Spacing (4pt grid)
```
xs:   4pt
sm:   8pt
sm+:  12pt
md:   16pt
lg:   24pt
xl:   32pt
2xl:  40pt
3xl:  56pt
```

Use as: `.padding(.md)` via a SwiftUI extension on `CGFloat`:
```swift
extension CGFloat {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let smPlus: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xl2: CGFloat = 40
    static let xl3: CGFloat = 56
}
```

### Corner Radius
```
tag/chip:   6pt
button:     10pt
input/row:  14pt
card:       20pt
sheet:      20pt (top corners only for bottom sheets)
```

### Component Patterns

**InspirationCard**
- Surface background, card radius (20pt)
- Platform label (Label style, teal dot indicator)
- Title (Heading weight)
- User note (Caption, secondary color)
- Footer: alignment badge + score
- Badge colors: strong = primary tint/text, consider = surface/secondary, skip = danger tint/text

**StoryCard**
- Surface background, card radius (20pt)
- Story title (Heading weight)
- Counts label: "3 assets · 2 references" (Caption, secondary)
- Status badge: draft (surface/secondary) / ready (primary tint/primary) / archived (surface/tertiary)
- Last updated relative timestamp (Caption, tertiary)

**AlignmentBadge**
- Capsule shape, 4pt vertical / 10pt horizontal padding
- Three states only: strong, consider, skip
- Never use for anything other than alignment verdict

**Primary Button**
- Fill: primary (#F0AA20), Text: #111111
- Height: 50pt, full width preferred
- Radius: 10pt, font: .callout weight .medium

**Secondary Button**
- Fill: surface elevated, Text: primary
- Border: 0.5pt, border default color

**Ghost Button / Teal Button / Danger Button**
- All follow same structure: tinted fill + matching text color
- Never solid fill for teal or danger — tinted only

---

## MVP Feature Scope

Build in this order. Do not skip ahead.

### Phase 1 — Foundation (build first)
1. Supabase project setup: schema, RLS, pgvector
2. Edge Function scaffolding (empty functions with correct signatures)
3. Xcode project setup with folder structure
4. Design system implementation (RiffitColors, spacing, typography extensions)
5. Authentication flow (Apple Sign In via Supabase)

### Phase 2 — Onboarding
6. Creator type selection screen
7. AI interview flow (branching by creator type)
8. CreatorProfile creation from interview output
9. Social account connection (optional, skippable)

### Phase 3 — Inspiration Capture
10. Main inspiration library view
11. Share extension (iOS share sheet integration)
12. In-app webview for video playback
13. Audio transcription via AssemblyAI Edge Function
14. Alignment scoring via Claude Edge Function
15. InspirationCard display with verdict

### Phase 4 — Storybank
16. Story list view (StorybankView) with create/delete
17. StoryDetailView with assets section + references section
18. Add text assets
19. Add voice note / video / image assets (media picker)
20. Add references from Library (pick video + tag)
21. AI relevance note generation via Edge Function

### Phase 5 — Deconstruction (v2)
22. VideoDeconstruction generation
23. Brief generation from Story + references (premium feature)

### Phase 6 — Monetization
25. RevenueCat integration
26. Free vs Pro entitlement gating
27. Paywall screen

---

## Edge Functions Reference

### `analyze-video`
Input: `{ url: string, platform: string, creator_profile_id: string }`
1. Calls AssemblyAI to transcribe audio
2. Saves InspirationVideo record
3. Triggers `score-alignment`
4. Triggers `generate-deconstruction`
Returns: `{ inspiration_video_id: string }`

### `score-alignment`
Input: `{ inspiration_video_id: string, creator_profile_id: string }`
1. Fetches InspirationVideo transcript
2. Fetches CreatorProfile (niche, pillars, tone, never_do)
3. Calls Claude API with alignment scoring prompt
4. Saves score, verdict, reasoning back to InspirationVideo
Returns: `{ score: number, verdict: string, reasoning: string }`

### `generate-relevance-note`
Input: `{ story_id: string, inspiration_video_id: string, reference_tag: string }`
1. Fetches Story title and existing assets
2. Fetches InspirationVideo transcript and user note
3. Calls Claude API to generate a one-sentence relevance note
4. Saves ai_relevance_note to StoryReference
Returns: `{ ai_relevance_note: string }`

### `run-interview`
Input: `{ session_id: string, user_message: string }`
1. Fetches OnboardingSession (conversation_history, creator_type)
2. Selects correct interview prompt tree based on creator_type
3. Calls Claude API with full conversation history
4. Appends AI response to conversation_history
5. Detects completion, extracts structured data, creates CreatorProfile
Returns: `{ ai_message: string, is_complete: boolean }`

### `transcribe-audio`
Input: `{ audio_url: string }`  (Supabase Storage URL)
1. Calls AssemblyAI transcription API
2. Polls until complete
3. Returns transcript with word-level timestamps
Returns: `{ transcript: string, words: [{text, start, end}] }`

---

## Folder Structure (Xcode Project)

```
Riffit/
├── App/
│   ├── RiffitApp.swift          -- @main entry point
│   ├── AppState.swift           -- global app state (auth, onboarding)
│   └── MainTabView.swift        -- 3-tab layout: Library / Storybank / Settings
├── Core/
│   ├── Design/
│   │   ├── RiffitColors.swift   -- color token environment object
│   │   ├── RiffitSpacing.swift  -- spacing constants
│   │   └── RiffitFonts.swift    -- typography helpers
│   ├── Network/
│   │   ├── SupabaseClient.swift -- singleton Supabase client
│   │   └── EdgeFunctions.swift  -- typed wrappers for each Edge Function
│   └── Extensions/
│       └── View+Riffit.swift    -- common SwiftUI view modifiers
├── Models/
│   ├── User.swift
│   ├── CreatorProfile.swift
│   ├── IdeaComment.swift
│   ├── IdeaFolder.swift
│   ├── InspirationVideo.swift
│   ├── Story.swift
│   ├── StoryAsset.swift
│   ├── StoryReference.swift
│   └── VideoDeconstruction.swift
├── Features/
│   ├── Auth/
│   │   ├── AuthView.swift
│   │   └── AuthViewModel.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingViewModel.swift
│   │   └── Steps/
│   │       ├── CreatorTypeView.swift
│   │       └── InterviewView.swift
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   ├── LibraryViewModel.swift
│   │   ├── AddInspirationView.swift
│   │   ├── InspirationDetailView.swift
│   │   └── FolderDetailView.swift
│   ├── Storybank/
│   │   ├── StorybankView.swift
│   │   ├── StorybankViewModel.swift
│   │   ├── StoryDetailView.swift
│   │   └── AddReferenceView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Components/
│   ├── InspirationCard.swift    -- reusable card component
│   ├── AlignmentBadge.swift
│   ├── RiffitButton.swift       -- primary/secondary/ghost/danger variants
│   └── LoadingOverlay.swift
└── ShareExtension/
    └── ShareViewController.swift
```

---

## Navigation Structure

Tab bar with 3 tabs:
1. **Library** (house icon) — Inspiration library, the main feed
2. **Storybank** (bookmark icon) — Creative workspace for organizing stories
3. **Settings** (gear icon) — Profile, subscription, preferences

No tab bar shown during onboarding. Onboarding is a full-screen modal flow dismissed permanently once complete.

---

## SwiftUI Patterns to Always Follow

```swift
// ALWAYS: ViewModel per feature screen
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var videos: [InspirationVideo] = []
    @Published var isLoading = false
    @Published var error: Error?

    func fetchVideos() async { ... }
}

// ALWAYS: Inject ViewModel as StateObject in parent, ObservedObject in child
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    // ...
}

// ALWAYS: Break complex views into named subviews
struct LibraryView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: .md) {
                ForEach(viewModel.videos) { video in
                    InspirationCard(video: video)
                }
            }
        }
    }
}

// ALWAYS: Handle loading and error states
if viewModel.isLoading {
    ProgressView()
} else if let error = viewModel.error {
    ErrorView(error: error)
} else {
    // content
}

// NEVER: Business logic in View body
// NEVER: Direct API calls from a View
// NEVER: Force unwraps
// NEVER: Hardcoded color hex values in Views
```

---

## AI Prompt Principles

When writing Claude API prompts inside Edge Functions:

1. **Always include CreatorProfile context** — niche, tone_markers, never_do, content_pillars
2. **Alignment scoring prompt** must be opinionated — return a clear verdict with reasoning. Don't hedge.
3. **Brief generation prompt** must reference specific story entries by title, not just "your stories"
4. **Interview prompt** must be conversational, warm, and curious — not a form. One question at a time.
5. **Creator type branching** — maintain separate system prompts per creator type:
   - `personal_brand`: focus on origin story, defining moments, opinions
   - `educator`: focus on expertise, frameworks, audience transformation
   - `entertainer`: focus on format, personality, recurring bits
   - `business`: focus on product, customer pain, proof points
   - `agency`: focus on client results, positioning, team voice

---

## Supabase Setup Checklist

Before writing any Swift code, complete:
- [ ] Create Supabase project at supabase.com
- [ ] Enable pgvector extension: `create extension vector`
- [ ] Run schema SQL for all tables
- [ ] Enable RLS on all tables and add policies
- [ ] Enable Apple OAuth provider in Supabase Auth settings
- [ ] Create storage bucket: `voice-notes` (private)
- [ ] Create storage bucket: `thumbnails` (public)
- [ ] Deploy all 5 Edge Functions with environment variables:
      - `ANTHROPIC_API_KEY`
      - `ASSEMBLYAI_API_KEY`
      - `REVENUECAT_WEBHOOK_SECRET`

---

## Things Claude Code Should Never Do

- Put an API key in Swift code
- Use UIKit when SwiftUI works
- Skip error handling
- Write business logic in a SwiftUI View body
- Use force unwraps (`!`)
- Hardcode color values — always use RiffitColors tokens
- Skip RLS policies on a new table
- Call external APIs directly from the iOS client
- Mix light/dark hardcoded colors — always use the token system

---

## Current Status

- [x] Requirements defined
- [x] Data model designed
- [x] Architecture decided
- [x] Design system complete
- [x] Xcode project created
- [x] Library tab: ideas, folders, drag-and-drop, detail view with comments
- [x] Storybank tab: story list, detail view with assets + references
- [ ] Supabase project created
- [ ] Media asset recording/picking (voice, video, image)
- [ ] AI relevance note generation
- [ ] Persistence (Supabase integration)

Next action: Create Supabase project → run schema → connect iOS to Supabase.
