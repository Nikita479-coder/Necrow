/*
  # Fix user profile creation to include full_name from auth metadata

  1. Changes
    - Update create_user_profile() function to extract full_name from auth.users raw_user_meta_data
    - This ensures full_name is saved immediately when a user signs up
    - Fixes issue where users show "No name" in admin dashboard

  2. Security
    - Function remains SECURITY DEFINER to allow insertion into user_profiles
    - Only extracts data from the auth.users record being created
*/

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (
    id, 
    referral_code,
    full_name
  )
  VALUES (
    NEW.id, 
    generate_referral_code(),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NULL)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
