/*
  # Fix referral code handling during signup

  1. Changes
    - Update create_user_profile trigger to handle referral_code from user metadata
    - Referral code is now processed during profile creation (atomic operation)
    - This avoids RLS issues when updating profile after signup

  2. Security
    - Uses SECURITY DEFINER to bypass RLS during profile creation
    - Validates referral code exists before linking
*/

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_referral_code TEXT;
BEGIN
  -- Get referral code from user metadata if provided
  v_referral_code := UPPER(TRIM(COALESCE(NEW.raw_user_meta_data->>'referral_code', '')));
  
  -- Look up referrer if referral code was provided
  IF v_referral_code != '' THEN
    SELECT id INTO v_referrer_id
    FROM user_profiles
    WHERE referral_code = v_referral_code;
  END IF;

  -- Create user profile with referral if found
  INSERT INTO user_profiles (
    id, 
    referral_code,
    full_name,
    referred_by
  )
  VALUES (
    NEW.id, 
    generate_referral_code(),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NULL),
    v_referrer_id
  );

  -- Initialize wallets for new user
  PERFORM initialize_user_wallets(NEW.id);

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE LOG 'Error in create_user_profile: % %', SQLERRM, SQLSTATE;
    RAISE;
END;
$$;
