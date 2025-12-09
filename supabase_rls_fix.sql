-- Enable RLS on posts table
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read all posts
CREATE POLICY "Anyone can view posts"
ON public.posts
FOR SELECT
TO authenticated
USING (true);

-- Allow users to insert their own posts
CREATE POLICY "Users can create posts"
ON public.posts
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = author_id);

-- Allow users to update their own posts
CREATE POLICY "Users can update own posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (auth.uid() = author_id);

-- Allow users to delete their own posts
CREATE POLICY "Users can delete own posts"
ON public.posts
FOR DELETE
TO authenticated
USING (auth.uid() = author_id);
