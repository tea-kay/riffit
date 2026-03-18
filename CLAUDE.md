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

> Full brand decisions locked March 2026. Every UI decision flows from this section.
> Never deviate from these tokens. Never hardcode values in views.

---

### Brand Identity

**App name:** Riffit
**Tagline:** scroll, riff, post
**Brand voice:** Confident, warm, creative. Never corporate. Never generic.
**Design personality:** Dark creative studio meets 70s surf culture. Approachable but opinionated.
**Inspiration:** Wave barrel at sunset — cool focused teal on the outside, warm explosive gold on the inside.

---

### Color Tokens

#### Dark Mode
```
Background:          #111111   — screen background
Surface:             #1C1C1C   — cards, sheets, list rows
Elevated:            #272727   — modals, popovers, dropdowns
Border subtle:       rgba(255,255,255, 0.07)
Border default:      rgba(255,255,255, 0.10)

Text primary:        #F2F0EB   — titles, headings (warm off-white, not pure white)
Text secondary:      #888888   — body, descriptions
Text tertiary:       #444444   — timestamps, metadata

Primary:             #F0AA20   — sunset gold — buttons, active states, scores
Primary pressed:     #E87820   — amber — pressed/active state
Primary tint:        rgba(240,170,32, 0.12)  — badge backgrounds
Primary ghost:       rgba(240,170,32, 0.06)  — hover, selected rows
Primary text light:  #C88A00   — gold for TEXT on light backgrounds (a11y)

Teal 900:            #0A4A52   — darkest teal, structural/shadow use
Teal 600:            #0F6B75   — secondary actions, info, storybank
Teal 400:            #1A8A96   — links, interactive hints, lighter teal
Teal tint:           rgba(15,107,117, 0.15)  — storybank badges, tag backgrounds

Danger:              #D94E2A   — coral burn — errors, skip verdict, destructive ONLY
Danger tint:         rgba(217,78,42, 0.12)
Danger text:         #D94E2A   — on dark backgrounds
```

#### Light Mode
```
Background:          #F5F2EB   — warm off-white beige (NOT pure white)
Surface:             #FFFFFF   — cards (white lifts off beige)
Elevated:            #FFFFFF   — modals with subtle shadow
Border subtle:       rgba(0,0,0, 0.06)
Border default:      rgba(0,0,0, 0.10)

Text primary:        #1A1A1A
Text secondary:      #888888
Text tertiary:       #AAAAAA

Primary fill:        #F0AA20   — same on buttons (dark text on gold always works)
Primary text:        #C88A00   — REQUIRED for gold text/labels on light bg
Primary tint:        rgba(200,138,0, 0.10)
Primary ghost:       rgba(200,138,0, 0.05)

Teal 600:            #0F6B75   — sufficient contrast on light backgrounds
Teal tint:           rgba(15,107,117, 0.08)

Danger:              #C03D1E   — slightly darker for light mode legibility
Danger tint:         rgba(217,78,42, 0.08)
```

#### Grid background (empty states + splash only)
```
Grid background:     #F0EBD8   — warmer than F5F2EB, used behind illustrations
Grid line color:     #D8D0BC   — 0.4px stroke
Grid line spacing:   85pt vertical, 73pt horizontal
```

#### The rule
```
Gold gets your attention.
Teal gives you context.
Coral means stop.
Everything else gets out of the way.
```

---

### Typography

**Display/hero text uses Georgia italic — this is the brand voice.**
Body and UI text uses SF Pro (iOS system font).
Never use SF Pro for page titles or the wordmark.

```
Display:     Georgia italic    32pt   weight 900    #1A1A1A / #F2F0EB
Page title:  Georgia italic    26pt   weight 900    #1A1A1A / #F2F0EB
             (Ideas, Storybank, Settings headings)
Heading:     SF Pro            17pt   weight 600    text primary
Body:        SF Pro            16pt   weight 400    text primary
Callout:     SF Pro            15pt   weight 400    text primary
Subhead:     SF Pro            14pt   weight 400    text secondary
Caption:     SF Pro            12pt   weight 400    text secondary
Label:       SF Pro            11pt   weight 500    + tracking 0.06em + UPPERCASE
Tagline:     Georgia italic    13pt   weight 400    teal 400 / letter-spacing 1
```

In SwiftUI:
```swift
// Page titles
Text("Ideas")
    .font(.custom("Georgia-BoldItalic", size: 26))
    .foregroundColor(colors.textPrimary)

// Tagline
Text("scroll, riff, post")
    .font(.custom("Georgia-Italic", size: 13))
    .foregroundColor(colors.teal400)
    .kerning(1.0)
```

---

### Spacing (4pt grid — always use these constants, never raw numbers)

```swift
extension CGFloat {
    static let xs: CGFloat    = 4
    static let sm: CGFloat    = 8
    static let smPlus: CGFloat = 12
    static let md: CGFloat    = 16
    static let lg: CGFloat    = 24
    static let xl: CGFloat    = 32
    static let xl2: CGFloat   = 40
    static let xl3: CGFloat   = 56
}
```

---

### Corner Radius

```
tag / chip:      6pt
button:          10pt
input / row:     14pt
card:            20pt
sheet:           20pt  (top corners only for bottom sheets)
modal:           24pt
```

---

### Logo & Wordmark

**Wordmark construction:**
- Font: Georgia Bold Italic
- Fill: #F0AA20 (sunset gold)
- Outline layer 1 (inner): #E87820, 4pt stroke, round join
- Outline layer 2 (mid): #0F6B75 teal, 10–16pt stroke, round join
- Shadow layer: #0A4A52, offset +2pt down-right
- Result: fat bubbly gold letters with teal outline and deep teal shadow

**Tagline:** "scroll, riff, post" — Georgia italic, 13pt, #0F6B75 teal, letter-spacing 1

**App icon construction (all sizes):**
- Background: #111111 with rx matching Apple's icon radius
- Monogram: italic R in Georgia Bold Italic
- Gold fill (#F0AA20) + teal stroke (#0F6B75) + coral shadow (#D94E2A)
- Swoosh accent below R: gold, 2pt stroke, rounded
- At 29px and below: gold R only on black, no stroke detail

**Icon sizes to implement:**
```
1024×1024   App Store
180×180     @3x home screen
120×120     @2x home screen
87×87       @3x settings
80×80       @2x spotlight
60×60       @3x notification
40×40       @2x spotlight
29×29       settings
20×20       notification
```

---

### Empty States

Every tab has a custom illustrated empty state. Never use SF Symbols alone.
Always use Georgia italic for empty state headlines.
Always use the wave/surf visual language.

#### Library (Ideas) — light mode
```
Background:      #F0EBD8 with grid lines (#D8D0BC, 0.4px, 85/73pt spacing)
Illustration:    Wave barrel — concentric teal rings with sunset inside
                 Rings: #1A8A96 → #0F6B75 → #0A4A52 (outer to inner)
                 Sunset: #F0AA20 → #E87820 → #D94E2A (outer to inner)
                 White foam stroke at top of barrel
                 Two teal water lines below
Headline:        "Nothing here yet" — Georgia Bold Italic, 18pt, #111111
Subtext:         "Catch a reel. Drop it here." — Georgia Italic, 12pt, #888
Button:          "Drop your first reel" — gold fill, Georgia Bold Italic, round 10pt
Stars:           ★ decorations at #F0AA20 and #0F6B75, flanking headline
```

#### Library — dark mode
```
Background:      #111111
Illustration:    Film reel — #1C1C1C body, dashed teal outer ring
                 Gold center dot, #272727 spokes and holes
                 Stripe accents flanking (teal/gold/coral stacks)
Headline:        "Nothing here yet" — Georgia Bold Italic, #F5F2EB
Subtext:         "Find a reel. Steal the idea." — Georgia Italic, #555
Button:          Ghost style — gold border + gold text, transparent fill
```

#### Storybank empty state
```
Light:  Surfboard illustration (gold board, teal + coral stripes, Riffit badge on board)
        "Your board is empty" / "Start building your first story."
Dark:   Same surfboard, inverted palette
```

#### Settings empty state
```
N/A — settings always has content
```

#### Empty state copy rules
- Headlines: Georgia Bold Italic always
- Use surf/wave metaphors: catch, reel, wave, board, drop, ride
- Never use generic app copy ("No items found", "Get started")
- Button copy: action verb first, specific ("Drop your first reel" not "Add Idea")

---

### Component Patterns

#### InspirationCard
```
Background:      Surface color
Border radius:   20pt
Padding:         16pt all sides

Platform row:    Caption label (11pt, 500 weight, uppercase, letter-spacing 0.06)
                 + colored dot (6pt circle, gold for active, #444 for inactive)
Title:           Heading weight, text primary, line-height 1.4
User note:       Caption, text secondary, line-height 1.5, italic
Footer:          AlignmentBadge (left) + score text (right, text tertiary)

Tap:             Opens video in in-app WebView
Long press:      Context menu (Archive, Copy URL, Add to Story)
```

#### AlignmentBadge
```
Strong fit:   background primary-tint (#F0AA20·12%)   text #F0AA20 / light: #C88A00
Consider:     background surface elevated             text text-secondary
Skip:         background danger-tint (#D94E2A·12%)    text #D94E2A / light: #C03D1E

Shape:        Capsule, 4pt vertical / 10pt horizontal padding
Font:         11pt, 500 weight
Never use for anything except alignment verdict.
```

#### Tag pills (capture sheet + filter bar)
```
Unselected:   Surface elevated fill, border default stroke, text secondary
Selected:     Primary tint fill, primary border (0.5pt), primary text
Font:         12pt, 500 weight
Radius:       20pt (full capsule)
Height:       32pt
Min width:    fit content + 16pt horizontal padding

Default tags: Hook · Editing · B-Roll · Format · Topic · Inspiration
```

#### StoryCard (Storybank list)
```
Background:      Surface
Border radius:   20pt
Padding:         16pt

Title:           Heading, Georgia italic preferred for story titles
Asset count:     "3 assets · 2 references" — Caption, text tertiary
Status badge:    draft (surface/secondary) · ready (teal tint/teal)
Updated time:    Caption, text tertiary, trailing
```

#### StoryEntryRow (asset inside a Story)
```
Icon container:  32×32pt, 8pt radius
                 Voice note: teal tint fill, teal waveform icon
                 Video: teal tint fill, teal play icon
                 Image: teal tint fill, teal photo icon
                 Text: teal tint fill, teal text icon
Title:           13pt, 500 weight, text primary
Preview:         12pt, text tertiary, 1 line truncated
Tag pill:        teal tint + teal text, 10pt
```

#### ReferenceCard (Library video pulled into Story)
```
Background:      Surface with teal-tint left border (3pt)
Border radius:   14pt
User note:       Italic, text secondary
Tag pill:        Selected state (primary color)
AI note:         12pt, text tertiary, italic — "Why this is relevant..."
Thumbnail:       48×48pt, 8pt radius, trailing
```

#### Capture bottom sheet
```
Drag handle:     36×4pt pill, surface elevated, centered, 8pt from top
URL preview:     Surface elevated pill, teal camera icon, truncated URL
Note field:      "What caught your eye?" placeholder, no label
                 Georgia italic, 15pt
Tag row:         Horizontal scroll, tag pills (see above)
Save button:     Full width primary, "Drop it" or "Save to Library"
Dismiss:         Swipe down or tap outside
Required fields: NONE — all optional, URL is sufficient
```

#### Buttons
```
Primary:      fill #F0AA20   text #111111   font Georgia Bold Italic 15pt
              height 50pt, full width preferred, radius 10pt

Secondary:    fill surface elevated   text primary   border 0.5pt border-default
              height 44pt, radius 10pt

Teal:         fill teal-tint   text teal-400   border 0.5pt teal
              height 44pt, radius 10pt

Ghost:        fill transparent   text primary   border 0.5pt border-default

Danger:       fill danger-tint   text danger   border 0.5pt danger
              Only for destructive/permanent actions

Disabled:     opacity 0.4 on any of the above, non-interactive
```

---

### Navigation

**3 tabs** (Briefs removed — brief generation is v2 Pro feature inside Stories):

```
Tab 1:  Library    (house icon)      — Inspiration feed
Tab 2:  Storybank  (bookmark icon)   — Creative workspace
Tab 3:  Settings   (gear icon)       — Profile, subscription, preferences
```

Tab bar styling:
```
Background:      Surface with top border (0.5pt, border-subtle)
Active icon:     Primary gold (#F0AA20)
Active label:    Primary gold, 10pt, 500 weight
Inactive:        Text tertiary
Active tab bg:   Primary ghost (subtle selected pill behind icon+label)
```

No tab bar shown during onboarding. Onboarding is full-screen modal,
dismissed permanently once onboarding_complete = true on User record.

---

### Motion & Interaction

```
Standard transition:    .easeInOut, 0.25s
Sheet presentation:     .spring(response: 0.4, dampingFraction: 0.85)
Card tap feedback:       scaleEffect(0.97) on press, .easeInOut 0.1s
Button press:           scaleEffect(0.96) + opacity(0.9) on press
Loading state:          ProgressView() tinted primary gold
Skeleton loading:       Surface elevated shimmer (redacted view modifier)
```

---

### Writing Style (microcopy)

```
Surf/wave vocabulary preferred:  catch, reel, ride, drop, barrel, wave, board
Avoid generic app copy:          "Get started", "No items", "Add new"
Personality words:               riff, remix, steal (the idea), your wave
Verbs first in buttons:          "Drop your first reel" not "Add First Reel"
Italic serif for brand moments:  headlines, empty states, CTAs, tagline
Uppercase for labels only:       tags, platform names, section labels
Numbers are human:               "2 hours ago" not "2h" — "3 assets" not "3"
```

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
- [x] Media asset recording/picking (voice, video, image)
- [x] Settings tab: account, appearance, influences analytics
- [x] Asset export to Camera Roll
- [x] Notes threads on ideas and stories
- [ ] Supabase project created
- [ ] Persistence (Supabase integration)
- [ ] Onboarding flow
- [ ] RevenueCat subscription logic
- [ ] Share extension functionality
- [ ] Test target + tests
- [ ] CI configuration

Next action: Create Supabase project → run schema → connect iOS to Supabase.

---

## Session Startup

> **Every new Claude Code session must start with this.**
> Copy the prompt template below, fill in the bracketed fields,
> and paste it as the first message. This prevents Claude from
> jumping into code without understanding what exists.

### Prompt Template

```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read these files to understand the current state:
- [file path 1]
- [file path 2]

Task: [one thing only — describe what and why, not how]

Design constraints:
- Never hardcode colors — always use RiffitColors tokens
- All fonts via RiffitTheme (RF/RS/RR typealiases)
- All spacing from RiffitTheme.Spacing constants
- No force unwraps — use if let, guard let, or optional chaining
- No UIKit unless there is no SwiftUI equivalent
- Comments explaining WHY, not just what
- New files must be added to project.pbxproj

Do not change anything outside the scope of this task.
Build. Confirm zero errors.
Report: files created, files modified, zero build errors confirmed.
```

### Template Variants

**For a bug fix:**
```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read:
- [file where the bug lives]

One fix only: [describe the bug and expected behavior]

Do not change anything else.
Build. Confirm zero errors.
Report: exactly what changed and in which file.
```

**For a new feature:**
```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read these files to understand the current state:
- [relevant model file]
- [relevant view file]
- [relevant viewmodel file]

Task: [what to build — describe the feature, not the implementation]

Architecture decisions — follow these exactly:
- [any specific patterns to use, e.g. "use flat list approach"]
- [any specific data model requirements]

View layout:
- [describe sections, rows, components]
- [describe interactions: tap, long-press, drag]

Design constraints:
- Never hardcode colors — always use RiffitColors tokens
- All fonts via RiffitTheme
- No force unwraps
- No UIKit

Do not change anything outside the scope of this task.
Build. Confirm zero errors.
Report: files created, files modified, zero build errors confirmed.
```

**For a read-only audit:**
```
Read CLAUDE.md and CONTEXT.md fully before writing any code.

Then read:
- [files to audit]

Tell me:
1. [specific question]
2. [specific question]

Do not write any code. Report only.
```

### What Makes a Good Prompt

Based on sessions that went well:
- **One task per prompt.** Never combine a bug fix with a feature.
- **Describe what and why, not how.** Let Claude figure out the implementation.
  Exception: design tokens and architecture constraints — be explicit.
- **Name the files to read.** Claude won't guess which files are relevant.
- **State what NOT to change.** "Do not touch SettingsView" prevents drift.
- **End with a build check.** "Build. Confirm zero errors." catches regressions.
- **Ask Claude to read before writing.** "Read X. Then tell me what you see."
  before "Now change it" catches misunderstandings early.

### After Every Session

Two files to update:

**1. Overwrite CONTEXT.md** with the current state of the app.
Only current state — no history. This file should always answer
"what does the app look like right now?" If models, file structure,
or decisions changed, update those sections. If nothing structural
changed, just update the "Last updated" date.

**2. Append to CHANGES.md** using this template:

```markdown
### YYYY-MM-DD — [short description]

**What changed:**
- [bullet per feature/fix, include file names]

**Decisions made:**
- [any new "do not re-add" items or architecture choices]

**Files created:**
- [list new files only]

**Files modified:**
- [list modified files only]

**Build status:** Zero errors confirmed
```

### Project Documentation Map

```
CLAUDE.md              — Architecture, rules, design tokens, prompt templates
CONTEXT.md             — Current state only (overwrite each session)
CHANGES.md             — Append-only changelog with dates
DESIGN_SYSTEM_UPDATE.md — Visual design spec (stable, rarely changes)
docs/history/          — Archived old context files
```
