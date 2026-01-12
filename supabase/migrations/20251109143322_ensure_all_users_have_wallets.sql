/*
  # Ensure All Users Have Wallets

  ## Description
  This migration ensures that all existing users have properly initialized
  wallets with starting balance. This fixes issues where users might not
  have wallet records.

  ## Changes
  - Inserts wallet records for any users missing them
  - Sets initial balance to 10,000 USDT for testing
*/

-- Create wallets for any users that don't have them
INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited)
SELECT 
  u.id,
  'USDT',
  10000,
  0,
  10000
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM wallets w 
  WHERE w.user_id = u.id AND w.currency = 'USDT'
)
ON CONFLICT (user_id, currency) DO NOTHING;

-- Also create BTC, ETH, BNB wallets for users who don't have them
INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited)
SELECT 
  u.id,
  c.currency,
  0,
  0,
  0
FROM auth.users u
CROSS JOIN (
  SELECT 'BTC' as currency
  UNION ALL SELECT 'ETH'
  UNION ALL SELECT 'BNB'
) c
WHERE NOT EXISTS (
  SELECT 1 FROM wallets w 
  WHERE w.user_id = u.id AND w.currency = c.currency
)
ON CONFLICT (user_id, currency) DO NOTHING;