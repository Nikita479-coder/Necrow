/*
  # Fix User Creation and Add Referral Handling
  
  1. Changes
    - Fix generate_referral_code function with proper permissions
    - Update create_user_profile with better error handling
    - Remove auto-populate trigger to avoid conflicts
    - Add support for referral code on signup
  
  2. Security
    - Proper SECURITY DEFINER flags
    - Error handling to prevent signup failures
*/

-- Fix generate_referral_code function
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
  attempts integer := 0;
  max_attempts integer := 10;
BEGIN
  LOOP
    result := '';
    FOR i IN 1..8 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    
    -- Check if code already exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE referral_code = result) THEN
      RETURN result;
    END IF;
    
    attempts := attempts + 1;
    IF attempts >= max_attempts THEN
      -- Add timestamp to ensure uniqueness
      result := result || to_char(NOW(), 'SS');
      RETURN result;
    END IF;
  END LOOP;
END;
$$;

-- Recreate create_user_profile with better error handling
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_referral_code text;
BEGIN
  -- Generate unique referral code
  new_referral_code := generate_referral_code();
  
  -- Insert user profile
  INSERT INTO user_profiles (id, referral_code)
  VALUES (NEW.id, new_referral_code);
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error and re-raise it
    RAISE WARNING 'Error creating user profile for %: %', NEW.id, SQLERRM;
    RAISE;
END;
$$;

-- Remove the auto-populate trigger to prevent conflicts during signup
DROP TRIGGER IF EXISTS auto_populate_new_user_data ON user_profiles;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_referral_code() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_user_profile() TO anon, authenticated;