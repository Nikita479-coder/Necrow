/*
  # Fix create_user_profile to also initialize wallets

  1. Problem
    - Users were not getting wallets created on signup
    
  2. Solution
    - Update create_user_profile to also call initialize_user_wallets
*/

CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create user profile
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
  
  -- Initialize wallets for new user
  PERFORM initialize_user_wallets(NEW.id);
  
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE LOG 'Error in create_user_profile: % %', SQLERRM, SQLSTATE;
    RAISE;
END;
$$;
