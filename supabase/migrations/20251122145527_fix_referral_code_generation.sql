/*
  # Fix Referral Code Generation

  1. Problem
    - create_user_profile() is SECURITY DEFINER without SET search_path
    - Cannot find generate_referral_code() function during execution
    - User creation fails with "function does not exist" error
    
  2. Solution
    - Add SET search_path to both functions
    - Ensure functions can find each other
    
  3. Security
    - Maintains SECURITY DEFINER for privilege elevation
    - Explicitly sets search path for security and reliability
*/

-- Recreate generate_referral_code with proper search_path
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    -- Generate 8 character code
    FOR i IN 1..8 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    
    -- Check if code already exists
    IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE referral_code = result) THEN
      RETURN result;
    END IF;
    
    attempts := attempts + 1;
    IF attempts >= max_attempts THEN
      -- If we've tried too many times, add a timestamp suffix for uniqueness
      result := result || to_char(now(), 'SSMS');
      RETURN result;
    END IF;
  END LOOP;
END;
$$;

-- Recreate create_user_profile with proper search_path
CREATE OR REPLACE FUNCTION public.create_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referral_code text;
  v_attempts integer := 0;
  v_max_attempts integer := 5;
BEGIN
  -- Try to generate a unique referral code
  LOOP
    v_referral_code := public.generate_referral_code();
    
    BEGIN
      INSERT INTO user_profiles (id, referral_code)
      VALUES (NEW.id, v_referral_code)
      ON CONFLICT (id) DO NOTHING;
      
      -- If we get here, insert succeeded
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        v_attempts := v_attempts + 1;
        IF v_attempts >= v_max_attempts THEN
          -- Last resort: use UUID suffix
          v_referral_code := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
          INSERT INTO user_profiles (id, referral_code)
          VALUES (NEW.id, v_referral_code)
          ON CONFLICT (id) DO NOTHING;
          EXIT;
        END IF;
        -- Otherwise, retry the loop
    END;
  END LOOP;
  
  RETURN NEW;
END;
$$;
