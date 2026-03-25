-- Migration 003: Story Collaboration
-- Adds tables and policies for multi-user story collaboration.
-- See specs:/STORY_COLLABORATION.md for the full feature spec.
--
-- DO NOT RUN AUTOMATICALLY — review and apply manually in Supabase SQL Editor.

-- ============================================================
-- 1. New table: story_collaborators
-- ============================================================

CREATE TABLE story_collaborators (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id        uuid REFERENCES stories(id) ON DELETE CASCADE,
    user_id         uuid REFERENCES users(id) ON DELETE CASCADE,
    role            text CHECK (role IN ('owner', 'editor', 'viewer', 'commenter', 'collaborator')) DEFAULT 'collaborator',
    invited_by      uuid REFERENCES users(id),
    status          text CHECK (status IN ('pending', 'accepted', 'declined')) DEFAULT 'pending',
    created_at      timestamptz DEFAULT now(),
    accepted_at     timestamptz,
    last_viewed_at  timestamptz,
    UNIQUE(story_id, user_id)
);

ALTER TABLE story_collaborators ENABLE ROW LEVEL SECURITY;

-- Owners can manage all collaborators on their stories
CREATE POLICY "owners can manage collaborators" ON story_collaborators
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM stories
            WHERE stories.id = story_collaborators.story_id
            AND stories.creator_profile_id IN (
                SELECT id FROM creator_profiles WHERE user_id = auth.uid()
            )
        )
    );

-- Collaborators can see their own records + other members on stories they belong to
CREATE POLICY "collaborators can view shared story members" ON story_collaborators
    FOR SELECT USING (
        user_id = auth.uid()
        OR story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

-- Users can accept/decline their own pending invitations
CREATE POLICY "users can respond to invitations" ON story_collaborators
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 2. New table: story_invite_links
-- ============================================================

CREATE TABLE story_invite_links (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id          uuid REFERENCES stories(id) ON DELETE CASCADE,
    created_by        uuid REFERENCES users(id),
    role              text CHECK (role IN ('editor', 'viewer', 'commenter', 'collaborator')) DEFAULT 'collaborator',
    referral_user_id  uuid REFERENCES users(id),
    token             text UNIQUE NOT NULL,
    expires_at        timestamptz,
    max_uses          int,
    use_count         int DEFAULT 0,
    created_at        timestamptz DEFAULT now()
);

ALTER TABLE story_invite_links ENABLE ROW LEVEL SECURITY;

-- Only the link creator (story owner) can manage their invite links
CREATE POLICY "owners can manage invite links" ON story_invite_links
    FOR ALL USING (created_by = auth.uid());

-- Anyone with the token can read the link (needed for join flow)
CREATE POLICY "anyone can read invite links by token" ON story_invite_links
    FOR SELECT USING (true);

-- ============================================================
-- 3. Alter users table: add referred_by for referral tracking
-- ============================================================

ALTER TABLE users ADD COLUMN referred_by uuid REFERENCES users(id);

-- ============================================================
-- 4. Alter story_notes table: add user_id for permission checks
-- ============================================================
-- Notes currently only have authorName (display string).
-- user_id links the note to an authenticated user so RLS and
-- "delete others' notes" permission can be enforced.

ALTER TABLE story_notes ADD COLUMN user_id uuid REFERENCES users(id);

-- ============================================================
-- 5. Updated RLS policies for collaborator access
-- ============================================================
-- These ADD new policies alongside the existing owner-only policies.
-- Existing "users can only access own data" policies remain — they
-- cover the owner case. These new policies extend access to
-- accepted collaborators.

-- story_assets: collaborators can READ
CREATE POLICY "collaborators can read shared story assets" ON story_assets
    FOR SELECT USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

-- story_assets: editors can INSERT
CREATE POLICY "editors can insert shared story assets" ON story_assets
    FOR INSERT WITH CHECK (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_assets: editors can UPDATE
CREATE POLICY "editors can update shared story assets" ON story_assets
    FOR UPDATE USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_assets: editors can DELETE
CREATE POLICY "editors can delete shared story assets" ON story_assets
    FOR DELETE USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_references: collaborators can READ
CREATE POLICY "collaborators can read shared story references" ON story_references
    FOR SELECT USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

-- story_references: editors can INSERT
CREATE POLICY "editors can insert shared story references" ON story_references
    FOR INSERT WITH CHECK (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_references: editors can UPDATE
CREATE POLICY "editors can update shared story references" ON story_references
    FOR UPDATE USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_references: editors can DELETE
CREATE POLICY "editors can delete shared story references" ON story_references
    FOR DELETE USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor')
        )
    );

-- story_notes: collaborators with note permission can READ
CREATE POLICY "collaborators can read shared story notes" ON story_notes
    FOR SELECT USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

-- story_notes: owner/editor/commenter/collaborator can INSERT notes
CREATE POLICY "note-permitted roles can insert shared story notes" ON story_notes
    FOR INSERT WITH CHECK (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor', 'commenter', 'collaborator')
        )
    );

-- story_notes: users can UPDATE their own notes (edit own note text)
CREATE POLICY "users can update own shared story notes" ON story_notes
    FOR UPDATE USING (
        user_id = auth.uid()
        AND story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('owner', 'editor', 'commenter', 'collaborator')
        )
    );

-- story_notes: owners can DELETE any note; others can delete only their own
CREATE POLICY "owners can delete any shared story note" ON story_notes
    FOR DELETE USING (
        story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role = 'owner'
        )
    );

CREATE POLICY "users can delete own shared story notes" ON story_notes
    FOR DELETE USING (
        user_id = auth.uid()
        AND story_id IN (
            SELECT story_id FROM story_collaborators
            WHERE user_id = auth.uid()
            AND status = 'accepted'
            AND role IN ('editor', 'commenter', 'collaborator')
        )
    );
