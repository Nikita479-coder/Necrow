/*
  # Backfill full_name from auth.users metadata to user_profiles

  1. Changes
    - Update all user_profiles records where full_name is NULL
    - Extract full_name from auth.users.raw_user_meta_data
    - Only update records that have a full_name in their metadata

  2. Notes
    - This is a one-time data migration
    - Fixes existing users who signed up before the trigger was updated
    - Future signups will automatically have full_name populated
*/

UPDATE user_profiles up
SET full_name = au.raw_user_meta_data->>'full_name'
FROM auth.users au
WHERE up.id = au.id
AND up.full_name IS NULL
AND au.raw_user_meta_data->>'full_name' IS NOT NULL
AND au.raw_user_meta_data->>'full_name' != '';
