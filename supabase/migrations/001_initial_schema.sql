-- ============================================================
-- Riffit Initial Schema
-- ============================================================
-- This migration creates the full database schema for Riffit MVP.
-- It enables pgvector for semantic search, creates all tables,
-- enables Row Level Security on every table, and adds indexes
-- on frequently queried columns.
-- ============================================================

-- Enable pgvector extension for semantic search on StoryBank
create extension if not exists vector with schema extensions;

-- ============================================================
-- Users
-- ============================================================
create table public.users (
    id              uuid primary key default gen_random_uuid(),
    email           text not null unique,
    full_name       text not null,
    avatar_url      text,
    subscription_tier text not null default 'free'
        check (subscription_tier in ('free', 'pro')),
    onboarding_complete boolean not null default false,
    created_at      timestamptz not null default now()
);

alter table public.users enable row level security;

create policy "users can read own data"
    on public.users for select
    using (auth.uid() = id);

create policy "users can update own data"
    on public.users for update
    using (auth.uid() = id);

create policy "users can insert own data"
    on public.users for insert
    with check (auth.uid() = id);

-- Index: look up user by email (for auth flows)
create index idx_users_email on public.users (email);

-- ============================================================
-- Creator Profiles
-- ============================================================
create table public.creator_profiles (
    id                    uuid primary key default gen_random_uuid(),
    user_id               uuid not null references public.users(id) on delete cascade,
    creator_type          text not null
        check (creator_type in ('personal_brand', 'educator', 'entertainer', 'business', 'agency')),
    niche                 text not null,
    mission_statement     text not null,
    target_audience       text not null,
    content_pillars       text[] not null default '{}',
    tone_markers          text[] not null default '{}',
    never_do              text[] not null default '{}',
    hot_takes             text[] not null default '{}',
    interview_transcript  jsonb,
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now()
);

alter table public.creator_profiles enable row level security;

create policy "users can access own creator profiles"
    on public.creator_profiles for all
    using (auth.uid() = user_id);

-- Index: look up profiles by user_id (most common query path)
create index idx_creator_profiles_user_id on public.creator_profiles (user_id);

-- ============================================================
-- Onboarding Sessions
-- ============================================================
-- Resumable — user can drop off and pick up without losing progress.
create table public.onboarding_sessions (
    id                      uuid primary key default gen_random_uuid(),
    user_id                 uuid not null references public.users(id) on delete cascade,
    creator_type_selected   text,
    current_step            int not null default 0,
    conversation_history    jsonb not null default '[]',
    completed_at            timestamptz,
    created_at              timestamptz not null default now()
);

alter table public.onboarding_sessions enable row level security;

create policy "users can access own onboarding sessions"
    on public.onboarding_sessions for all
    using (auth.uid() = user_id);

-- Index: look up sessions by user_id
create index idx_onboarding_sessions_user_id on public.onboarding_sessions (user_id);

-- ============================================================
-- Story Entries (StoryBank)
-- ============================================================
-- The creator's personal narrative library.
-- Powers the "in your voice" remixing via pgvector semantic search.
create table public.story_entries (
    id                  uuid primary key default gen_random_uuid(),
    creator_profile_id  uuid not null references public.creator_profiles(id) on delete cascade,
    title               text not null,
    body_text           text not null,
    voice_note_url      text,
    source              text not null
        check (source in ('manual', 'voice', 'ai_interview', 'extracted')),
    category            text not null
        check (category in ('career', 'win', 'failure', 'opinion', 'background', 'other')),
    tags                text[] not null default '{}',
    embedding           vector(1536),
    created_at          timestamptz not null default now()
);

alter table public.story_entries enable row level security;

-- RLS joins back to user_id through creator_profiles
create policy "users can access own story entries"
    on public.story_entries for all
    using (
        creator_profile_id in (
            select id from public.creator_profiles
            where user_id = auth.uid()
        )
    );

-- Index: look up stories by creator profile
create index idx_story_entries_creator_profile_id on public.story_entries (creator_profile_id);

-- Index: category filtering
create index idx_story_entries_category on public.story_entries (category);

-- Index: pgvector HNSW index for fast semantic search
-- Using cosine distance which works well for normalized embeddings
create index idx_story_entries_embedding on public.story_entries
    using hnsw (embedding vector_cosine_ops);

-- ============================================================
-- Inspiration Videos
-- ============================================================
create table public.inspiration_videos (
    id                    uuid primary key default gen_random_uuid(),
    creator_profile_id    uuid not null references public.creator_profiles(id) on delete cascade,
    url                   text not null,
    platform              text not null
        check (platform in ('instagram', 'tiktok', 'youtube', 'linkedin', 'x')),
    user_note             text,
    thumbnail_url         text,
    transcript            text,
    alignment_score       int
        check (alignment_score >= 0 and alignment_score <= 100),
    alignment_verdict     text
        check (alignment_verdict in ('skip', 'consider', 'strong')),
    alignment_reasoning   text,
    status                text not null default 'pending'
        check (status in ('pending', 'analyzing', 'analyzed', 'archived')),
    saved_at              timestamptz not null default now()
);

alter table public.inspiration_videos enable row level security;

create policy "users can access own inspiration videos"
    on public.inspiration_videos for all
    using (
        creator_profile_id in (
            select id from public.creator_profiles
            where user_id = auth.uid()
        )
    );

-- Index: look up videos by creator profile
create index idx_inspiration_videos_creator_profile_id on public.inspiration_videos (creator_profile_id);

-- Index: filter by status (pending, analyzing, analyzed, archived)
create index idx_inspiration_videos_status on public.inspiration_videos (status);

-- Index: filter by platform
create index idx_inspiration_videos_platform on public.inspiration_videos (platform);

-- Index: sort by saved date (most common sort order)
create index idx_inspiration_videos_saved_at on public.inspiration_videos (saved_at desc);

-- ============================================================
-- Video Deconstructions
-- ============================================================
-- One-to-one with InspirationVideo. Created after analysis.
create table public.video_deconstructions (
    id                    uuid primary key default gen_random_uuid(),
    inspiration_video_id  uuid not null unique references public.inspiration_videos(id) on delete cascade,
    hook_text             text not null,
    hook_type             text not null
        check (hook_type in ('question', 'stat', 'story', 'bold_claim', 'visual')),
    full_transcript       text not null,
    structure_segments    jsonb[] not null default '{}',
    broll_moments         jsonb[] not null default '{}',
    transition_notes      text,
    cut_count             int not null,
    pacing                text not null
        check (pacing in ('slow', 'medium', 'fast')),
    created_at            timestamptz not null default now()
);

alter table public.video_deconstructions enable row level security;

-- RLS joins back through inspiration_videos -> creator_profiles -> users
create policy "users can access own video deconstructions"
    on public.video_deconstructions for all
    using (
        inspiration_video_id in (
            select iv.id from public.inspiration_videos iv
            join public.creator_profiles cp on iv.creator_profile_id = cp.id
            where cp.user_id = auth.uid()
        )
    );

-- Index: look up deconstruction by video (unique already creates this, but explicit for clarity)
-- The unique constraint on inspiration_video_id already provides an index.

-- ============================================================
-- Content Briefs
-- ============================================================
-- The primary output — the thing the creator takes into filming.
create table public.content_briefs (
    id                    uuid primary key default gen_random_uuid(),
    inspiration_video_id  uuid not null references public.inspiration_videos(id) on delete cascade,
    creator_profile_id    uuid not null references public.creator_profiles(id) on delete cascade,
    remixed_concept       text not null,
    remixed_hook          text not null,
    sections              jsonb[] not null default '{}',
    shot_list             jsonb[] not null default '{}',
    story_refs            uuid[] not null default '{}',
    user_selections       jsonb,
    status                text not null default 'draft'
        check (status in ('draft', 'active', 'done', 'archived')),
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now()
);

alter table public.content_briefs enable row level security;

create policy "users can access own content briefs"
    on public.content_briefs for all
    using (
        creator_profile_id in (
            select id from public.creator_profiles
            where user_id = auth.uid()
        )
    );

-- Index: look up briefs by creator profile
create index idx_content_briefs_creator_profile_id on public.content_briefs (creator_profile_id);

-- Index: look up briefs by inspiration video
create index idx_content_briefs_inspiration_video_id on public.content_briefs (inspiration_video_id);

-- Index: filter by status
create index idx_content_briefs_status on public.content_briefs (status);

-- Index: sort by updated date
create index idx_content_briefs_updated_at on public.content_briefs (updated_at desc);

-- ============================================================
-- Social Accounts
-- ============================================================
-- Connected social platforms for brand context.
create table public.social_accounts (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references public.users(id) on delete cascade,
    platform            text not null
        check (platform in ('instagram', 'tiktok', 'youtube', 'linkedin', 'x')),
    handle              text not null,
    follower_count      int,
    avg_views           int,
    top_performing_tags text[],
    connected_at        timestamptz not null default now(),
    -- Prevent duplicate platform connections per user
    unique (user_id, platform)
);

alter table public.social_accounts enable row level security;

create policy "users can access own social accounts"
    on public.social_accounts for all
    using (auth.uid() = user_id);

-- Index: look up accounts by user_id
create index idx_social_accounts_user_id on public.social_accounts (user_id);

-- ============================================================
-- Helper function: auto-update updated_at on row modification
-- ============================================================
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- Apply updated_at trigger to tables that have an updated_at column
create trigger set_updated_at
    before update on public.creator_profiles
    for each row execute function public.handle_updated_at();

create trigger set_updated_at
    before update on public.content_briefs
    for each row execute function public.handle_updated_at();
