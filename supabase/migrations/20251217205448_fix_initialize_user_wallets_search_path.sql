/*
  # Fix initialize_user_wallets function search_path

  1. Problem
    - The initialize_user_wallets function lacks a search_path setting
    
  2. Solution
    - Recreate the function with proper search_path = public
*/

CREATE OR REPLACE FUNCTION initialize_user_wallets(user_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, wallet_type)
  VALUES
    (user_uuid, 'USDT', 0, 0, 0, 'main'),
    (user_uuid, 'BTC', 0, 0, 0, 'main'),
    (user_uuid, 'ETH', 0, 0, 0, 'main'),
    (user_uuid, 'BNB', 0, 0, 0, 'main')
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
END;
$$;
