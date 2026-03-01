/*
  # Add Initial Balance for Testing

  ## Description
  This migration gives all existing users an initial balance of 10,000 USDT
  for testing the futures trading system.

  ## Changes
  - Updates all existing USDT wallets with 10,000 USDT balance
  - Sets total_deposited to match the balance
*/

-- Give all existing users 10,000 USDT for testing
UPDATE wallets
SET 
  balance = 10000,
  total_deposited = 10000,
  updated_at = now()
WHERE currency = 'USDT' AND balance = 0;

-- Also update the initialize_user_wallets function to give new users starting balance
CREATE OR REPLACE FUNCTION initialize_user_wallets(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited)
  VALUES
    (user_uuid, 'USDT', 10000, 0, 10000),
    (user_uuid, 'BTC', 0, 0, 0),
    (user_uuid, 'ETH', 0, 0, 0),
    (user_uuid, 'BNB', 0, 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;