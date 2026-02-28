/*
  # Fix ensure_copy_wallet - Include All Required Fields
  
  ## Problem
  The ensure_copy_wallet function only specifies 4 columns when inserting wallets,
  which might cause NULL values in other non-null columns.
  
  ## Solution
  Update to include all required numeric fields explicitly.
*/

-- Update ensure_copy_wallet to use all required fields
CREATE OR REPLACE FUNCTION ensure_copy_wallet(p_user_id uuid, p_wallet_type text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
  )
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET
    balance = COALESCE(wallets.balance, 0),
    locked_balance = COALESCE(wallets.locked_balance, 0),
    total_deposited = COALESCE(wallets.total_deposited, 0),
    total_withdrawn = COALESCE(wallets.total_withdrawn, 0);
END;
$$;
