-- =============================================
-- SUPABASE STORAGE SETUP INSTRUCTIONS
-- =============================================

-- STEP 1: Create buckets in Supabase Dashboard
-- Go to Storage > Create Bucket:
-- 1. Create bucket named "avatars" (Public: ON)
-- 2. Create bucket named "photos" (Public: ON)

-- STEP 2: Create bucket policies in Supabase Dashboard
-- Go to Storage > [bucket name] > Policies
-- Create these policies for both 'avatars' and 'photos' buckets:

-- Policy 1: "Users can upload files"
-- Operation: INSERT
-- Target roles: authenticated
-- Policy definition: true

-- Policy 2: "Anyone can view files" 
-- Operation: SELECT
-- Target roles: public
-- Policy definition: true

-- Policy 3: "Users can update own files"
-- Operation: UPDATE  
-- Target roles: authenticated
-- Policy definition: auth.uid()::text = (storage.foldername(name))[1]

-- Policy 4: "Users can delete own files"
-- Operation: DELETE
-- Target roles: authenticated  
-- Policy definition: auth.uid()::text = (storage.foldername(name))[1]