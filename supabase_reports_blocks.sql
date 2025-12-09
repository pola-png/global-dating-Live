-- Create reports table
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL CHECK (report_type IN ('harassment', 'spam', 'inappropriate_content', 'fake_profile', 'other')),
  context TEXT NOT NULL CHECK (context IN ('individual_chat', 'group_chat', 'post', 'profile')),
  context_id UUID, -- chat_room_id for individual chat, group_id for group chat, post_id for posts
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create blocked_users table
CREATE TABLE IF NOT EXISTS public.blocked_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  blocker_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_user_id)
);

-- Enable RLS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- RLS policies for reports
CREATE POLICY "Users can create reports"
ON public.reports
FOR INSERT
TO authenticated
WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view their own reports"
ON public.reports
FOR SELECT
TO authenticated
USING (reporter_id = auth.uid());

-- RLS policies for blocked_users
CREATE POLICY "Users can block others"
ON public.blocked_users
FOR INSERT
TO authenticated
WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "Users can view their blocked list"
ON public.blocked_users
FOR SELECT
TO authenticated
USING (blocker_id = auth.uid());

CREATE POLICY "Users can unblock others"
ON public.blocked_users
FOR DELETE
TO authenticated
USING (blocker_id = auth.uid());

-- Update messages policy to exclude blocked users
DROP POLICY IF EXISTS "Users can view messages in their chat rooms" ON public.messages;
CREATE POLICY "Users can view messages in their chat rooms"
ON public.messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.chat_rooms 
    WHERE chat_rooms.id = messages.chat_room_id 
    AND (chat_rooms.user1_id = auth.uid() OR chat_rooms.user2_id = auth.uid())
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = auth.uid() AND blocked_user_id = messages.sender_id)
    OR (blocker_id = messages.sender_id AND blocked_user_id = auth.uid())
  )
);