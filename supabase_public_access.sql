-- Drop existing restrictive policy
DROP POLICY IF EXISTS "Anyone can view posts" ON public.posts;

-- Create new policy allowing public read access (including anonymous users)
CREATE POLICY "Public can view posts"
ON public.posts
FOR SELECT
TO public
USING (true);

-- Also allow public read access to users table for author info
DROP POLICY IF EXISTS "Public can view user profiles" ON public.users;

CREATE POLICY "Public can view user profiles"
ON public.users
FOR SELECT
TO public
USING (true);