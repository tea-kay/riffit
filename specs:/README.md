# /specs — Feature Specs for Riffit

Every feature gets a markdown spec before code is written.
Claude Code reads these directly — that's the whole point.

## How to use

1. Copy `TEMPLATE.md` → rename to `FEATURE_NAME.md`
2. Fill in every section (delete what doesn't apply)
3. When ready to build, paste the "Claude Code Prompt" section from the spec into Claude Code
4. After building, update the spec's **Status** field

## Current specs

| Spec | Status | Priority |
|---|---|---|
| EARN_REFERRAL_PROGRAM.md | Not started | P2 |
| STORY_COLLABORATION.md | Not started | P1 |
| DATA_PERSISTENCE.md | Not started (partial) | P0 |

## Rules

- One feature per spec file
- Specs are the source of truth — if the spec and the code disagree, update the spec first
- Infrastructure tasks (persistence, auth, CI) get specs too, just with fewer UI sections
- The Claude Code Prompt at the bottom of each spec is copy-paste ready
