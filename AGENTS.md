# Riffit — Engineering Standards for AI Agents

> Read this file at the start of every session, before CLAUDE.md.
> These are non-negotiable engineering principles learned from production bugs.
> Every principle exists because we shipped the wrong thing and had to fix it.

---

## Philosophy

Build like the problem is a physics equation, not a checklist.

Before writing code, ask: What is actually happening? Not what should be
happening, not what the last person assumed was happening — what is the
actual state of every variable, every async call, every render cycle at
the exact moment the bug occurs?

**First principles, not pattern matching.** Don't see a loading bug and
reach for "add a spinner." Trace the entire lifecycle: what triggers the
view, what data exists at render time, what async work is in flight, what
order do state changes propagate. The fix comes from understanding the
system, not from memorizing fixes.

**The fastest way to ship is to ship less.** One task per prompt. One fix
per commit. If a prompt has the word "also" in it, split it into two
prompts.

---

## How to Think (Debugging Protocol)

These rules exist because every major bug in this project came from
skipping the diagnosis step and jumping straight to a fix.

### Rule 1: Diagnose before you prescribe

Never assume you know the root cause. Before writing ANY fix:

1. **Trace the lifecycle.** Follow the actual code path from trigger to
   symptom. Write down every state change in order with line numbers.
2. **State your hypotheses.** List 2-3 possible causes, ranked by
   likelihood. Don't fall in love with the first one.
3. **Verify the hypothesis.** Read the actual code. Add debug prints if
   needed. Confirm which hypothesis is correct BEFORE writing the fix.
4. **Only then write the fix.** And scope it to exactly what's broken.

Bad: "The screen flickers → add hasLoadedOnce"
Good: "The screen flickers → fetchVideos fires on every .onAppear →
isLoading=true blanks the screen → hasLoadedOnce guard prevents re-fetch"

### Rule 2: Ask "why" five times

When you find a bug, the first answer is almost never the root cause.

- Why is the avatar popping in? → AsyncImage re-downloads every render
- Why does it re-download? → The URL changed (cache-busting timestamp)
- Why does a new URL matter? → AsyncImage has no .id() to force recreate
- Why wasn't .id() added? → It was added on Settings but not StoryCard
- Why the inconsistency? → No reusable AvatarView component exists

The fix isn't ".id()" — it's "build AvatarView, use it everywhere."

### Rule 3: Don't patch symptoms, fix architecture

If you're adding a safety net (deletedStoryIds, recentlyCreatedFolderIds),
that's a sign the real problem is upstream. Safety nets are acceptable as
temporary defense-in-depth, but always ask: "What would eliminate the need
for this safety net entirely?"

Symptoms we patched vs. architecture we should have built:

| Symptom | Patch | Real Fix |
|---|---|---|
| Deleted story reappears | deletedStoryIds filter | Await DELETE before fetch |
| New folder vanishes on tab switch | recentlyCreatedFolderIds | Await INSERT, fetch-once guard |
| Avatar pops in on cards | .id(url) on AsyncImage | Local UIImage cache, download once |
| Blank screen after sign-in | hasLoadedOnce poisoning fix | Three-way auth branch in RootView |
| Splash fades before data ready | dataReady flag | Splash gates on data, not just auth |

### Rule 4: Consider the full lifecycle, not just the happy path

Every feature has these moments. Think through all of them:

1. **Cold launch** — no cached data, no session
2. **Warm launch** — cached session, stale data
3. **First sign-in** — auth just completed, zero data
4. **Tab switch** — view reappears with existing data
5. **Background return** — app was suspended, data may be stale
6. **After mutation** — local state changed, server may lag
7. **Network failure** — server unreachable mid-operation
8. **Sign out and back in** — clean slate with new user

If your code only works for moments 2 and 4, it's not done.

---

## Data Loading Architecture

These five principles govern every ViewModel in the app. They exist
because we had four separate bugs from violating them.

### Principle 1: Fetch once, refresh explicitly

Every ViewModel fetches from Supabase exactly once on first appearance.
Subsequent tab switches use the in-memory cache. Fresh data comes only
from pull-to-refresh or after a mutation completes.

```swift
// ViewModel
@Published var hasLoadedOnce = false
@Published var isLoading = false

func fetchAll(userId: UUID?) async {
    guard let profileId = userId else {
        // Do NOT set hasLoadedOnce here. No data was fetched.
        // A future call with a valid userId must still be able to fetch.
        return
    }
    guard !isMutating else { return }  // Principle 3
    if !hasLoadedOnce { isLoading = true }

    // ... fetch from Supabase ...

    hasLoadedOnce = true
    isLoading = false
}
```

```swift
// View
.task {
    guard !viewModel.hasLoadedOnce else { return }
    await viewModel.fetchAll(userId: appState.currentUser?.id)
}
.refreshable {
    await viewModel.fetchAll(userId: appState.currentUser?.id)
}
```

**Why:** Library re-fetched on every tab switch, clobbering optimistic
state. Adding hasLoadedOnce to Library's fetch trigger eliminated the
flicker and the data loss.

### Principle 2: Mutations are awaited, never fire-and-forget

Every Supabase write (INSERT, UPDATE, DELETE) is `await`ed before the
calling context proceeds. The local array is updated optimistically AND
the server call completes before any dismiss or navigation happens.

```swift
// WRONG — fire-and-forget
func createFolder(name: String) {
    folders.append(newFolder)  // optimistic
    Task {
        try await supabase.from("folders").insert(newFolder).execute()
    }
    // caller dismisses immediately — race condition
}

// RIGHT — awaited
func createFolder(name: String) async {
    folders.append(newFolder)  // optimistic
    do {
        try await supabase.from("folders").insert(newFolder).execute()
    } catch {
        folders.removeAll { $0.id == newFolder.id }  // rollback
        print("createFolder FAILED: \(error)")
    }
}

// In the View:
Task {
    await viewModel.createFolder(name: name)
    dismiss()  // only after server confirms
}
```

**Why:** Every fire-and-forget mutation in the codebase eventually caused
a bug where the user saw data disappear. createFolder, deleteVideo,
addComment — all had the same race. Converting to async eliminated the
entire class of bugs.

### Principle 3: Fetches respect in-flight mutations

A simple `isMutating` flag on the ViewModel. If a mutation is in progress,
any fetch that triggers skips entirely.

```swift
@Published private var isMutating = false

private func beginMutation() { isMutating = true }
private func endMutation() { isMutating = false }

func createStory(...) async {
    beginMutation()
    defer { endMutation() }
    // ... optimistic add + awaited Supabase call ...
}

func fetchAll(userId: UUID?) async {
    guard !isMutating else { return }  // don't clobber in-flight mutation
    // ... fetch ...
}
```

**Why:** Even with awaited mutations, a pull-to-refresh or .onChange retry
could trigger a fetch while a mutation is mid-flight. The fetch would
replace the array with stale server data, wiping the optimistic add.

### Principle 4: One fetch method per ViewModel

All data for a feature loads in a single `fetchAll()` method with parallel
phases — not scattered across `fetchVideos()`, `fetchFolders()`,
`fetchTags()` separately.

```swift
func fetchAll(userId: UUID?) async {
    // Phase 1: Primary data (parallel)
    async let videos = supabase.from("inspiration_videos")...
    async let folders = supabase.from("inspiration_folders")...
    let (fetchedVideos, fetchedFolders) = try await (videos, folders)

    // Phase 2: Related data (parallel)
    async let tags = supabase.from("idea_tags")...
    async let comments = supabase.from("idea_comments")...
    async let folderMaps = supabase.from("idea_folder_map")...
    let (t, c, fm) = try await (tags, comments, folderMaps)

    // Single assignment point — all data arrives together
    self.videos = fetchedVideos
    self.folders = fetchedFolders
    // ...
    hasLoadedOnce = true
}
```

**Why:** Scattered fetches cause partial renders — stories appear but
avatars don't, cards paint but counts are wrong. One fetch method
guarantees the view has everything it needs before hasLoadedOnce flips.

### Principle 5: No visual pop-in

The view must have everything it needs to render completely on first paint.
No secondary async loads that cause layout shifts.

**For the current user's avatar:** Download once during auth, store as
UIImage on AppState, render from memory everywhere. Never use AsyncImage
for the current user's own face.

**For other users' avatars:** Batch-fetch all user info (name, avatar URL)
as part of the main fetchAll, BEFORE hasLoadedOnce flips. Use AsyncImage
with `.id(url)` and fixed-dimension placeholders.

**For any async image:** Always set a fixed `.frame(width:height:)` on
both the loaded image and the placeholder. Layout must not shift when the
image arrives.

**Why:** The avatar pop-in on StoryCards was caused by AsyncImage fetching
from a remote URL on every render. Four cards = four network requests for
the same JPEG. The fix: download once, cache locally, render from memory.

---

## View Loading Lifecycle

Every view that fetches data follows this exact lifecycle. No exceptions.

```
First load:          Color.clear — never flash empty state before data
Has data:            Render immediately from cached array
Empty (confirmed):   Show empty state ONLY after hasLoadedOnce && data.isEmpty
Pull-to-refresh:     System refresh indicator only
Tab switch:          Cached data renders instantly, no re-fetch
```

**View template:**
```swift
if !viewModel.hasLoadedOnce {
    Color.clear          // invisible — splash covers this
} else if viewModel.data.isEmpty {
    EmptyStateView()     // confirmed empty — show illustration
} else {
    ContentView()        // render data
}
```

**What never happens:**
- Empty state flash before first fetch completes
- Loading spinner on tab switch when cached data exists
- Loading spinner on background refresh
- Blank screen between splash fade and data paint

---

## App Startup Sequence

The app has two independent gates. Both must be satisfied before the user
sees content.

### Gate 1: Auth (controls what renders)
```
RootView three-way branch:
  if appState.isLoading    → Color.clear (splash covers)
  else if isAuthenticated  → MainTabView
  else                     → AuthView
```

MainTabView ONLY renders after auth resolves. This prevents ViewModels
from firing .task with nil userId.

### Gate 2: Data readiness (controls when splash fades)
```
Splash fades when appState.dataReady == true
dataReady is set after at least one tab's fetchAll completes
Timeout: 5 seconds max — splash fades anyway on failure
```

The splash gates on data, not just auth. Without this, the user sees
blank-then-paint between splash fade and fetchAll completing.

**Why this exists:** The original bug had the splash gating only on
`isLoading` (auth). Auth resolved in ~200ms, splash faded, but
fetchStories hadn't even started yet. The user saw 1-2 seconds of
Color.clear before data painted.

### The poisoning bug

If a ViewModel's .task fires with nil userId (before auth completes),
the guard must NOT set `hasLoadedOnce = true`. Setting it poisons
future fetches — the .task guard blocks any retry, and the screen
stays blank permanently.

```swift
// WRONG — poisons hasLoadedOnce
guard let profileId = userId else {
    hasLoadedOnce = true  // ← BUG: no data was fetched
    return
}

// RIGHT — leaves hasLoadedOnce false for retry
guard let profileId = userId else {
    return
}
```

---

## State Management Rules

### Single source of truth

Every piece of data has exactly one owner. All views read from that owner.
No local @State copies of server data. No @AppStorage for data that
belongs in Supabase.

| Data | Owner | Readers |
|---|---|---|
| Current user | AppState.currentUser | Every view via @EnvironmentObject |
| Current user's avatar | AppState.avatarImage (UIImage) | AvatarView component |
| Stories + assets | StorybankViewModel | StorybankView, StoryDetailView |
| Ideas + tags | LibraryViewModel | LibraryView, InspirationDetailView |
| Other users' info | StorybankViewModel.collaboratorUserInfo | SharedStoryCard, CollaboratorRow |

### When to use AsyncImage vs local UIImage

- **Current user's avatar:** Local UIImage on AppState. Downloaded once
  during fetchUser. Updated in-memory during uploadAvatar. Rendered via
  reusable AvatarView component. Zero network requests on render.
- **Other users' avatars:** AsyncImage with `.id(url)` and fixed-dimension
  placeholder. Batch-fetched during fetchAll, URLs in collaboratorUserInfo
  cache.
- **Content thumbnails:** AsyncImage is fine — these are many, varied,
  and not worth local caching in MVP.

### Computed properties over duplicated state

If a value can be derived from existing state, derive it. Don't store it.

```swift
// WRONG — duplicated state that gets out of sync
@Published var unfiledStories: [Story] = []

// RIGHT — computed from single source
var unfiledStories: [Story] {
    stories.filter { !sharedStoryIds.contains($0.id) && !folderedStoryIds.contains($0.id) }
}
```

---

## Mutation Patterns

### The template for every mutation

```swift
func doThing(param: X) async {
    beginMutation()
    defer { endMutation() }

    // 1. Optimistic local update
    localArray.append(newItem)

    // 2. Awaited server call
    do {
        try await supabase.from("table").insert(newItem).execute()
    } catch {
        // 3. Rollback on failure
        localArray.removeAll { $0.id == newItem.id }
        print("[ViewModel] doThing FAILED: \(error)")
    }
}
```

### In the View

```swift
// Views are synchronous — wrap in Task
Button("Create") {
    Task {
        await viewModel.doThing(param: value)
        dismiss()  // after server confirms
    }
}
```

### What never happens

- `Task { }` wrapping a Supabase call without await (fire-and-forget)
- Dismiss or navigation before the mutation completes
- A mutation method that isn't marked `async`
- A mutation that doesn't call beginMutation/endMutation

---

## Reusable Components

### DRY rule

If the same UI pattern appears in 3+ places, extract it into a reusable
component in Components/. If the same logic appears in 2+ ViewModels,
extract it into a service or extension.

**Components that exist because we violated DRY:**

| Pattern | Before | After |
|---|---|---|
| User avatar display | AsyncImage copy-pasted in 6 views | AvatarView component |
| Gold/ghost buttons | Inline styles duplicated | RiffitButton + RiffitGhostButtonStyle |
| Tag pill rendering | Duplicated in 3 sheets | TagPill (inside AddInspirationView) |
| Note/comment bubble | Duplicated in StoryDetail + InspirationDetail | Same iMessage pattern |

### Component contract

Every reusable component must:
1. Accept all data as parameters (no internal fetching)
2. Use design tokens (RiffitColors, RiffitTheme) — never hardcoded values
3. Have a fixed layout frame — no layout shifts when data loads
4. Work in both light and dark mode

---

## Prompt Engineering (for giving tasks to Claude Code)

### What works

- **One task per prompt.** Never combine a bug fix with a feature.
- **Describe what and why, not how.** Exception: design tokens and
  architecture constraints — be explicit about those.
- **Name the files to read.** Claude won't guess which files are relevant.
- **State what NOT to change.** "Do not touch SettingsView" prevents drift.
- **End with a build check.** "Build. Confirm zero errors."
- **Ask to read before write.** "Read X. Tell me what you see." Then in a
  follow-up: "Now change it." Catches misunderstandings early.

### What doesn't work

- Compound prompts with 4-6 tasks → Claude loses context, makes mistakes
- "Fix the loading bug" without specifying which loading behavior is wrong
- Asking for a fix without first asking for a diagnosis
- Prompts longer than ~80 lines → chunk into sequential prompts

### The diagnosis-then-fix pattern

For any bug, always use two prompts:

**Prompt 1 (read-only):**
```
Read [files]. Do NOT write any code.
Answer these questions with line numbers:
1. What triggers X?
2. What is the state of Y when Z happens?
3. Where does data flow from A to B?
Report only.
```

**Prompt 2 (fix):**
```
Based on the diagnosis: [paste findings]
One fix only: [describe the change]
Do not change anything else.
Build. Confirm zero errors.
```

### Prompt sizing rule

If a task touches more than 8 methods or 3 files, break it into
sequential prompts of ≤8 methods or ≤2 files each. Each prompt must
build and be testable independently.

**How to split:**
- Group by file (StorybankViewModel first, LibraryViewModel second)
- Group by feature area (mutations first, fetch logic second, UI third)
- Each prompt ends with "Build. Confirm zero errors."
- Each prompt starts with "Read AGENTS.md, CLAUDE.md and CONTEXT.md"
- Never assume the previous prompt's changes — read the files fresh

**When presenting prompts to the developer:** ALWAYS break large tasks
into numbered sequential prompts (Prompt 1, Prompt 2, Prompt 3...).
Never hand over a single prompt that tries to do everything. The
developer runs one, tests, then runs the next. This catches regressions
between steps instead of at the end of a 200-line mega-prompt.

**The rule of thumb:** If you're writing a prompt and it passes 60 lines,
stop and split it. Two 40-line prompts that each build clean will always
outperform one 80-line prompt that might half-work.

### After every session

1. **Overwrite CONTEXT.md** with current state (not history)
2. **Append to CHANGES.md** using the template in CLAUDE.md

---

## Debugging Checklist

When something looks wrong, work through this list in order:

### Data not appearing
1. Is fetchAll being called? Check .task trigger and hasLoadedOnce guard
2. Is userId nil when fetchAll fires? Check auth sequence
3. Is hasLoadedOnce being poisoned? Check the nil-userId guard
4. Is isMutating blocking the fetch? Check if a mutation is in-flight
5. Is the view reading from the right source? Check @Published bindings

### Data disappearing
1. Is a fetch clobbering optimistic state? Check isMutating guard
2. Is the mutation fire-and-forget? Check for `Task { }` without await
3. Is a tab switch triggering a re-fetch? Check hasLoadedOnce guard
4. Is the fetch doing full array replacement? Check for merge vs replace

### Visual pop-in / layout shift
1. Is AsyncImage downloading on every render? Use local UIImage cache
2. Does the placeholder have the same frame as the loaded image? Check .frame()
3. Is .id() set on AsyncImage? Without it, SwiftUI serves cached stale images
4. Is data being fetched in a secondary call? Batch into fetchAll

### Splash / loading state bugs
1. What gates the splash fade? Should be dataReady, not just auth
2. What gates MainTabView rendering? Should be three-way branch on AppPhase
3. Is there a timeout on the splash? Prevent infinite splash on network failure

---

## Code Quality Standards

### Swift-specific rules
- No force unwraps (`!`) — use `if let`, `guard let`, optional chaining
- No UIKit unless SwiftUI has no equivalent
- All colors via RiffitColors tokens — never hex values in views
- All fonts via RiffitTheme (RF/RS/RR typealiases)
- All spacing via RS constants — never raw numbers
- `@MainActor` on every ViewModel
- Explicit types over inferred when it aids readability
- Comments explain WHY, not what

### Naming
- ViewModels: `[Feature]ViewModel` (e.g. `StorybankViewModel`)
- Views: `[Feature]View` (e.g. `StorybankView`)
- Fetch methods: `fetchAll(userId:)` or `fetch[Entity](userId:)`
- Mutation methods: verb + noun (e.g. `createStory`, `deleteFolder`)
- Boolean flags: `is` or `has` prefix (e.g. `isLoading`, `hasLoadedOnce`)

### Error handling
- Every Supabase call wrapped in do/catch
- Catch block prints `[ClassName] methodName FAILED: \(error)`
- Mutations rollback optimistic state on failure
- Never silently swallow errors

### Architecture boundaries
- Views: UI only. No business logic. No direct Supabase calls.
- ViewModels: State + mutations + fetch. No UI code.
- AppState: Auth + global user state. No feature-specific data.
- Services: Reusable utilities (audio, image, video, export).
- Edge Functions: All AI + external API calls. Never from Swift.

---

## Things Claude Code Must Never Do

Copied from CLAUDE.md + expanded with lessons learned:

- Put an API key in Swift code
- Use UIKit when SwiftUI works
- Skip error handling
- Write business logic in a SwiftUI View body
- Use force unwraps (`!`)
- Hardcode color values — always use RiffitColors tokens
- Skip RLS policies on a new table
- Call external APIs directly from the iOS client
- Use fire-and-forget `Task {}` for Supabase writes — always await
- Show an empty state before the first data fetch completes
- Re-fetch data with a visible loading state on tab switch
- Set `hasLoadedOnce = true` when userId is nil (poisons future fetches)
- Use AsyncImage for the current user's avatar (download once, cache locally)
- Add a feature without considering all 8 lifecycle moments (see above)
- Write a fix without first diagnosing the root cause
- Combine multiple tasks in a single session
- Skip the build check at the end of every change

---

## Lessons Learned (The Hard Way)

These are real bugs we shipped and had to fix. Read them as cautionary
tales, not just rules.

### "It works on my machine" ≠ it works
The auth race bug only appeared on first sign-in. Cached sessions masked
it. Always test cold launch AND first sign-in AND sign-out-sign-back-in.

### Fire-and-forget is a time bomb
Every single `Task { try await supabase... }` without awaiting the result
eventually caused a user-visible bug. The INSERT hadn't landed when the
fetch ran. The DELETE hadn't committed when the view re-rendered. Convert
them all to awaited async methods.

### Optimistic UI without rollback is lying to the user
If you add to the local array but the server call fails, the user sees
data that doesn't exist. Always pair optimistic adds with catch-block
rollbacks.

### AsyncImage is not a cache
AsyncImage downloads from the network on every render unless SwiftUI's
internal cache happens to hold it. For data you control (user avatar),
download once and cache as UIImage. AsyncImage is for content you don't
control.

### Safety nets are technical debt
deletedStoryIds, recentlyCreatedFolderIds — these exist because mutations
weren't awaited and fetches weren't guarded. They work, but they're
symptoms of a deeper problem. When you add a safety net, comment WHY it
exists and what architectural fix would eliminate it.

### The splash screen is UX, not just polish
The splash originally gated on auth. Auth resolved in 200ms but data
took 1-2 seconds. The user saw blank-then-paint every cold launch. The
splash must gate on data readiness, not just authentication.

### .id() on AsyncImage matters
Without .id(url), AsyncImage serves cached stale images when the URL
changes (same path, different query parameter). SettingsView had .id(),
StoryCard didn't. Inconsistency = bug. Extract to a component.

### One source of truth, many readers
The avatar was read from appState.currentUser?.avatarUrl in 6 places.
All were "live" reads — no stale copies. But AsyncImage downloaded it
independently in each location. The fix: one download, one UIImage,
one AvatarView component, six readers.
