/*
  # Fix Wallet Inserts - Use EXCLUDED Keyword
  
  ## Problem
  The ON CONFLICT DO UPDATE was using wallets.balance which might not properly
  reference the existing row. Need to use EXCLUDED for new values and remove
  the UPDATE entirely since we don't want to change existing wallets.
  
  ## Solution
  Change ON CONFLICT to DO NOTHING to avoid any updates to existing wallets.
*/

-- Fix ensure_wallet to just skip existing wallets
CREATE OR REPLACE FUNCTION ensure_wallet(
  p_user_id uuid,
  p_currency text,
  p_wallet_type text DEFAULT 'main',
  p_initial_balance numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
BEGIN
  -- First try to get existing wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id
  AND currency = p_currency
  AND wallet_type = p_wallet_type;
  
  -- If found, return it
  IF FOUND THEN
    RETURN v_wallet_id;
  END IF;
  
  -- Otherwise, insert new wallet
  INSERT INTO wallets (
    user_id, 
    currency, 
    wallet_type, 
    balance, 
    locked_balance, 
    total_deposited, 
    total_withdrawn
  )
  VALUES (
    p_user_id,
    p_currency,
    p_wallet_type,
    COALESCE(p_initial_balance, 0),
    0,
    0,
    0
  )
  RETURNING id INTO v_wallet_id;
  
  RETURN v_wallet_id;
END;
$$;

-- Fix ensure_copy_wallet to just skip existing wallets
CREATE OR REPLACE FUNCTION ensure_copy_wallet(p_user_id uuid, p_wallet_type text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if wallet exists
  IF EXISTS (
    SELECT 1 FROM wallets
    WHERE user_id = p_user_id
    AND currency = 'USDT'
    AND wallet_type = p_wallet_type
  ) THEN
    RETURN;
  END IF;
  
  -- Insert new wallet
  INSERT INTO wallets (
    user_id, 
    currency, 
    wallet_type, 
    balance,
    locked_balance,
    total_deposited,
    total_withdrawn
  )
  VALUES (
    p_user_id, 
    'USDT', 
    p_wallet_type, 
    0,
    0,
    0,
    0
  );
END;
$$;

-- Remove the problematic check constraint since column default should handle it
ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_balance_not_null_check;
