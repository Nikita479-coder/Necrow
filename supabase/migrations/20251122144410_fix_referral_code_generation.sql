/*
  # Fix Referral Code Generation with Unique Check

  1. Changes
    - Update `generate_referral_code()` to check for uniqueness and retry
    - Update `create_user_profile()` to handle conflicts gracefully
    - Ensure no duplicate referral codes can be generated

  2. Security
    - Maintains SECURITY DEFINER for automatic execution
    - Prevents infinite loops with max retry limit
*/

-- Improved function to generate unique referral code with retry logic
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text AS $$
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
$$ LANGUAGE plpgsql;

-- Update function to auto-create profile on user signup with better error handling
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
DECLARE
  v_referral_code text;
  v_attempts integer := 0;
  v_max_attempts integer := 5;
BEGIN
  -- Try to generate a unique referral code
  LOOP
    v_referral_code := generate_referral_code();

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
$$ LANGUAGE plpgsql SECURITY DEFINER;