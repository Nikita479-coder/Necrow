/*
  # Set Initial Admin User

  1. Purpose
    - Grant admin privileges to the primary user for accessing admin panel
    
  2. Changes
    - Update user_profiles to set is_admin = true for almagilmore922@gmail.com
*/

UPDATE user_profiles
SET is_admin = true
WHERE id = '108fd40d-5c54-4828-956b-ac7dec71720a';
