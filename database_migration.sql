-- SQL Migration for Chaptr E-book App
-- Run these queries in your Supabase SQL Editor

-- 1. Add username column to comments table
ALTER TABLE comments 
ADD COLUMN IF NOT EXISTS username TEXT;

-- 2. Update existing comments with usernames from profiles table
UPDATE comments c
SET username = COALESCE(
  (SELECT username FROM profiles WHERE id = c.user_id),
  'Anonymous'
)
WHERE username IS NULL;

-- Optional: Set a default for future comments
ALTER TABLE comments 
ALTER COLUMN username SET DEFAULT 'Anonymous';

-- 3. Add parent_comment_id for reply functionality
ALTER TABLE comments 
ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE;

-- 4. Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- 'follow', 'comment', 'reply'
  book_id UUID REFERENCES books(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  from_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  from_username TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create index for faster notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- 6. Create index for comments parent lookup
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comments_book_id ON comments(book_id);
