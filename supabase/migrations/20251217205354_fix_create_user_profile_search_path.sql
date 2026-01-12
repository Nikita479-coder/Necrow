/*
  # Fix create_user_profile function search_path

  1. Problem
    - The create_user_profile trigger function lacks a search_path setting
    - This can cause "Database error saving new user" during signup

  2. Solution
    - Recreate the function with proper search_path = public
    - Ensure SECURITY DEFINER is set correctly
*/

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
$$;
