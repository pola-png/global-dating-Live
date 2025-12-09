-- FINAL, COMPLETE, AND CORRECTED SCRIPT FOR CHAT FUNCTIONALITY
-- Purpose: To ensure correct RLS policies on base tables and create views to solve the relationship error.

-- Step 1: Force a schema reload to clear any stale cache.
NOTIFY pgrst, 'reload schema';

-- ----------------------------------------
-- CLEANUP: Drop views to ensure they are created with the latest structure.
-- ----------------------------------------
DROP VIEW IF EXISTS public.messages_detailed;
DROP VIEW IF EXISTS public.group_messages_detailed;

-- ----------------------------------------
-- RLS Policies on Original Tables
-- ----------------------------------------

-- On 'users' table: Allow authenticated users to see each other's profiles.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can view all user profiles" ON public.users;
CREATE POLICY "Authenticated users can view all user profiles"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- On 'chat_rooms' table: Allow users to see chat rooms they are a part of.
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their chat rooms" ON public.chat_rooms;
CREATE POLICY "Users can view their chat rooms"
ON public.chat_rooms
FOR SELECT
TO authenticated
USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- On 'messages' table: Allow users to see messages in rooms they are in, and insert new ones.
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
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
);
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
CREATE POLICY "Users can send messages"
ON public.messages FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid());


-- On 'group_messages' table: Allow users to see all group messages and insert new ones.
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can view all group messages" ON public.group_messages;
CREATE POLICY "Authenticated users can view all group messages"
ON public.group_messages
FOR SELECT
TO authenticated
USING (true);
DROP POLICY IF EXISTS "Users can send group messages" ON public.group_messages;
CREATE POLICY "Users can send group messages"
ON public.group_messages FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());

-- ----------------------------------------
-- VIEW CREATION (The Fix for the App Error)
-- ----------------------------------------

-- View for Individual Chat Messages
CREATE OR REPLACE VIEW public.messages_detailed AS
SELECT
  m.id,
  m.created_at,
  m.text,
  m.sender_id,
  m.chat_room_id,
  m.reply_to_id,
  m.is_read,
  m.status,
  json_build_object(
    'full_name', u.full_name,
    'avatar_letter', u.avatar_letter
  ) AS sender
FROM
  public.messages m
LEFT JOIN
  public.users u ON m.sender_id = u.id;

-- View for Group Chat Messages
CREATE OR REPLACE VIEW public.group_messages_detailed AS
SELECT
  m.id,
  m.created_at,
  m.text,
  m.author_id,
  m.country_slug,
  json_build_object(
    'full_name', u.full_name,
    'avatar_letter', u.avatar_letter
  ) AS author
FROM
  public.group_messages m
LEFT JOIN
  public.users u ON m.author_id = u.id;

