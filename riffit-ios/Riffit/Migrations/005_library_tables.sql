-- Migration 005: Library supporting tables
-- Adds idea_comments, idea_tags, idea_folder_map tables.
-- inspiration_videos and inspiration_folders already exist from the initial schema.
--
-- DO NOT RUN AUTOMATICALLY — review and apply manually in Supabase SQL Editor.

-- ============================================================
-- 1. idea_comments — comment threads on ideas
-- ============================================================

CREATE TABLE IF NOT EXISTS idea_comments (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    inspiration_video_id    uuid REFERENCES inspiration_videos(id) ON DELETE CASCADE,
    user_id                 uuid REFERENCES users(id),
    author_name             text NOT NULL DEFAULT 'You',
    text                    text NOT NULL,
    created_at              timestamptz DEFAULT now()
);

ALTER TABLE idea_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage comments on own ideas" ON idea_comments
    FOR ALL USING (
        inspiration_video_id IN (
            SELECT id FROM inspiration_videos
            WHERE creator_profile_id = auth.uid()
        )
    );

-- ============================================================
-- 2. idea_tags — per-video tag assignments
-- ============================================================

CREATE TABLE IF NOT EXISTS idea_tags (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    inspiration_video_id    uuid REFERENCES inspiration_videos(id) ON DELETE CASCADE,
    tag                     text NOT NULL,
    UNIQUE(inspiration_video_id, tag)
);

ALTER TABLE idea_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage tags on own ideas" ON idea_tags
    FOR ALL USING (
        inspiration_video_id IN (
            SELECT id FROM inspiration_videos
            WHERE creator_profile_id = auth.uid()
        )
    );

-- ============================================================
-- 3. idea_folder_map — maps ideas to folders
-- ============================================================

CREATE TABLE IF NOT EXISTS idea_folder_map (
    inspiration_video_id    uuid REFERENCES inspiration_videos(id) ON DELETE CASCADE,
    folder_id               uuid REFERENCES inspiration_folders(id) ON DELETE CASCADE,
    PRIMARY KEY (inspiration_video_id)
);

ALTER TABLE idea_folder_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own folder mappings" ON idea_folder_map
    FOR ALL USING (
        inspiration_video_id IN (
            SELECT id FROM inspiration_videos
            WHERE creator_profile_id = auth.uid()
        )
    );

-- ============================================================
-- 4. user_tags — user's available tag list (custom tags persist per user)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_tags (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
    tag         text NOT NULL,
    UNIQUE(user_id, tag)
);

ALTER TABLE user_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own tags" ON user_tags
    FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- 5. Add user_id to inspiration_folders if missing
-- ============================================================
-- The initial schema may not have user_id on inspiration_folders.
-- This ensures RLS can scope folders to the user.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'inspiration_folders' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE inspiration_folders ADD COLUMN user_id uuid REFERENCES users(id);
    END IF;
END $$;
