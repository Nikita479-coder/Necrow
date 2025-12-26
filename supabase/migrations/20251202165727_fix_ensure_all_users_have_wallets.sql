/*
  # Ensure All Users Have Complete Wallet Setup

  ## Description
  This migration ensures all existing users have:
  1. Main wallet (USDT) with initial balance
  2. Futures margin wallet with initial balance
  3. Proper wallet configuration for trading

  ## Changes
  1. Create main USDT wallets for users who don't have one
  2. Create futures margin wallets for users who don't have one
  3. Add initial balance to help with testing
*/

-- Create main USDT wallet for users without one
INSERT INTO wallets (user_id, currency, balance, wallet_type)
SELECT 
  u.id,
  'USDT',
  10000.00,
  'main'
FROM auth.users u
LEFT JOIN wallets w ON w.user_id = u.id AND w.currency = 'USDT'
WHERE w.id IS NULL
ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

-- Create futures margin wallet for users without one
INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
SELECT 
  u.id,
  5000.00,
  0.00
FROM auth.users u
LEFT JOIN futures_margin_wallets fw ON fw.user_id = u.id
WHERE fw.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;
