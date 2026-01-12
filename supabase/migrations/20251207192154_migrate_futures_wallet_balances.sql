/*
  # Migrate Futures Wallet Balances

  ## Description
  Migrates all existing balances from wallets table (wallet_type='futures') 
  to the correct futures_margin_wallets table, then removes the incorrect 
  futures wallet entries.

  ## Changes
  - Transfers all USDT balances from wallets.wallet_type='futures' to futures_margin_wallets
  - Ensures all users have a futures_margin_wallets entry
  - Cleans up the incorrect futures wallet entries

  ## Security
  - Maintains all existing balances
  - No data loss
*/

-- Step 1: Ensure all users have a futures_margin_wallets entry
INSERT INTO futures_margin_wallets (user_id, available_balance)
SELECT DISTINCT user_id, 0
FROM wallets
WHERE wallet_type = 'futures'
ON CONFLICT (user_id) DO NOTHING;

-- Step 2: Migrate balances from wallets table to futures_margin_wallets
UPDATE futures_margin_wallets fm
SET 
  available_balance = fm.available_balance + COALESCE(w.balance, 0),
  updated_at = NOW()
FROM wallets w
WHERE w.user_id = fm.user_id
  AND w.wallet_type = 'futures'
  AND w.currency = 'USDT'
  AND w.balance > 0;

-- Step 3: Delete the incorrect futures wallet entries (keep only main and copy wallets)
DELETE FROM wallets
WHERE wallet_type = 'futures';