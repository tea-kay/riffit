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
