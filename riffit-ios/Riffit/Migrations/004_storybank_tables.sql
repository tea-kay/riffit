-- Migration 004: Storybank supporting tables
-- Adds story_notes, asset_sections, story_folders, and story_folder_map
-- that were previously in-memory only.
--
-- DO NOT RUN AUTOMATICALLY — review and apply manually in Supabase SQL Editor.
-- Run AFTER 003_story_collaboration.sql (which adds user_id to story_notes).

-- ============================================================
-- 1. story_notes — notes thread on stories
-- ============================================================

CREATE TABLE IF NOT EXISTS story_notes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    user_id         uuid REFERENCES users(id),
    author_name     text NOT NULL DEFAULT 'You',
    text            text NOT NULL,
    created_at      timestamptz DEFAULT now()
);

ALTER TABLE story_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can read notes on own stories" ON story_notes
    FOR SELECT USING (
        story_id IN (
            SELECT id FROM stories
            WHERE creator_profile_id IN (
                SELECT id FROM creator_profiles WHERE user_id = auth.uid()
            )
        )
        OR story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY "users can insert notes on own stories" ON story_notes
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND (
            story_id IN (
                SELECT id FROM stories
                WHERE creator_profile_id IN (
                    SELECT id FROM creator_profiles WHERE user_id = auth.uid()
                )
            )
            OR story_id IN (
                SELECT story_id FROM story_collaborators
                WHERE user_id = auth.uid() AND status = 'accepted'
            )
        )
    );

CREATE POLICY "users can update own notes" ON story_notes
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "users can delete own notes" ON story_notes
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- 2. asset_sections — named groupings within stories
-- ============================================================

CREATE TABLE IF NOT EXISTS asset_sections (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    name            text NOT NULL,
    display_order   int DEFAULT 0,
    created_at      timestamptz DEFAULT now()
);

ALTER TABLE asset_sections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage sections on own stories" ON asset_sections
    FOR ALL USING (
        story_id IN (
            SELECT id FROM stories
            WHERE creator_profile_id IN (
                SELECT id FROM creator_profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ============================================================
-- 3. story_folders — folder organization in Storybank
-- ============================================================

CREATE TABLE IF NOT EXISTS story_folders (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid REFERENCES users(id) ON DELETE CASCADE,
    name            text NOT NULL,
    created_at      timestamptz DEFAULT now()
);

ALTER TABLE story_folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own folders" ON story_folders
    FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- 4. story_folder_map — maps stories to folders
-- ============================================================

CREATE TABLE IF NOT EXISTS story_folder_map (
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    folder_id       uuid REFERENCES story_folders(id) ON DELETE CASCADE,
    PRIMARY KEY (story_id)
);

ALTER TABLE story_folder_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own folder mappings" ON story_folder_map
    FOR ALL USING (
        story_id IN (
            SELECT id FROM stories
            WHERE creator_profile_id IN (
                SELECT id FROM creator_profiles WHERE user_id = auth.uid()
            )
        )
    );
