/*
  # Fix All Trigger Functions Search Path

  1. Problem
    - Multiple SECURITY DEFINER trigger functions lack SET search_path
    - Functions cannot find tables during execution
    - User creation fails with "relation does not exist" errors
    
  2. Solution
    - Add SET search_path = public to all trigger functions
    - initialize_futures_margin_wallet
    - set_user_leverage_limit
    
  3. Security
    - Maintains SECURITY DEFINER for privilege elevation
    - Explicitly sets search path for security and reliability
*/

-- Fix initialize_futures_margin_wallet
CREATE OR REPLACE FUNCTION public.initialize_futures_margin_wallet()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO futures_margin_wallets (user_id, available_balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Fix set_user_leverage_limit
CREATE OR REPLACE FUNCTION public.set_user_leverage_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_kyc_level integer;
  v_max_leverage integer;
BEGIN
  -- Get user's KYC level
  SELECT kyc_level INTO v_kyc_level
  FROM user_profiles
  WHERE id = NEW.id;
  
  -- Determine max leverage based on KYC level
  -- 0 (unverified): 20x, 1 (basic): 50x, 2 (verified): 125x
  v_max_leverage := CASE
    WHEN v_kyc_level >= 2 THEN 125
    WHEN v_kyc_level = 1 THEN 50
    ELSE 20
  END;
  
  -- Insert or update leverage limit
  INSERT INTO user_leverage_limits (user_id, max_allowed_leverage)
  VALUES (NEW.id, v_max_leverage)
  ON CONFLICT (user_id) DO UPDATE
  SET max_allowed_leverage = v_max_leverage,
      updated_at = now();
  
  RETURN NEW;
END;
$$;
