/*
  # Enhanced Staking System and Wallet Type Support

  ## Summary
  This migration enhances the existing staking system with comprehensive cryptocurrency support
  and adds wallet type tracking to distinguish between main, assets, copy trading, and futures wallets.

  ## Changes Made

  ### 1. Wallet Type Support
  - Add `wallet_type` column to wallets table
  - Types: 'main', 'assets', 'copy', 'futures'
  - Update existing wallets to 'main' type
  - Update unique constraint to include wallet_type

  ### 2. Enhanced Staking Products
  - Add staking products for all major cryptocurrencies
  - Realistic APY rates based on current market standards
  - Multiple lock periods (flexible, 30-day, 60-day, 90-day)
  - Proper minimum amounts and pool caps

  ### 3. Staking Pools Added
  - BTC: 2.5% flexible, 4.0% 30-day, 5.5% 60-day, 7.0% 90-day
  - ETH: 3.5% flexible, 5.0% 30-day, 6.5% 60-day, 8.0% 90-day
  - BNB: 5.0% flexible, 7.5% 30-day, 10.0% 60-day, 12.5% 90-day
  - SOL: 6.0% flexible, 8.5% 30-day, 11.0% 60-day, 13.5% 90-day
  - USDT: 8.0% flexible, 10.0% 30-day, 12.0% 60-day, 15.0% 90-day
  - USDC: 7.5% flexible, 9.5% 30-day, 11.5% 60-day, 14.0% 90-day
  - XRP: 4.0% flexible, 6.0% 30-day, 8.0% 60-day, 10.0% 90-day
  - ADA: 4.5% flexible, 6.5% 30-day, 8.5% 60-day, 11.0% 90-day
  - DOGE: 3.0% flexible, 5.0% 30-day, 7.0% 60-day, 9.0% 90-day
  - DOT: 10.0% flexible, 12.5% 30-day, 15.0% 60-day, 18.0% 90-day
  - MATIC: 8.5% flexible, 11.0% 30-day, 13.5% 60-day, 16.0% 90-day
  - LTC: 3.5% flexible, 5.5% 30-day, 7.5% 60-day, 9.5% 90-day

  ## Security
  - All existing RLS policies remain in effect
  - Wallet type is user-controlled for flexibility
*/

-- Add wallet_type column to wallets table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wallets' AND column_name = 'wallet_type'
  ) THEN
    ALTER TABLE wallets ADD COLUMN wallet_type text NOT NULL DEFAULT 'main'
      CHECK (wallet_type IN ('main', 'assets', 'copy', 'futures'));
  END IF;
END $$;

-- Update unique constraint to include wallet_type
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'wallets_user_id_currency_key'
  ) THEN
    ALTER TABLE wallets DROP CONSTRAINT wallets_user_id_currency_key;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'wallets_user_id_currency_wallet_type_key'
  ) THEN
    ALTER TABLE wallets ADD CONSTRAINT wallets_user_id_currency_wallet_type_key 
      UNIQUE(user_id, currency, wallet_type);
  END IF;
END $$;

-- Create index for wallet_type queries
CREATE INDEX IF NOT EXISTS idx_wallets_user_wallet_type ON wallets(user_id, wallet_type);

-- Insert comprehensive staking products for all major cryptocurrencies
INSERT INTO earn_products (coin, product_type, apr, duration_days, min_amount, max_amount, total_cap, invested_amount, is_active, is_featured, badge) VALUES
-- Bitcoin (BTC)
('BTC', 'flexible', 2.50, 0, 0.001, NULL, 500, 0, true, true, 'Secure'),
('BTC', 'fixed', 4.00, 30, 0.001, NULL, 200, 0, true, false, NULL),
('BTC', 'fixed', 5.50, 60, 0.001, NULL, 150, 0, true, false, NULL),
('BTC', 'fixed', 7.00, 90, 0.001, NULL, 100, 0, true, false, 'High Yield'),

-- Ethereum (ETH)
('ETH', 'flexible', 3.50, 0, 0.01, NULL, 5000, 0, true, true, 'Popular'),
('ETH', 'fixed', 5.00, 30, 0.01, NULL, 2000, 0, true, false, NULL),
('ETH', 'fixed', 6.50, 60, 0.01, NULL, 1500, 0, true, false, NULL),
('ETH', 'fixed', 8.00, 90, 0.01, NULL, 1000, 0, true, false, 'High Yield'),

-- BNB
('BNB', 'flexible', 5.00, 0, 0.1, NULL, 10000, 0, true, true, 'Exchange Token'),
('BNB', 'fixed', 7.50, 30, 0.1, NULL, 5000, 0, true, false, NULL),
('BNB', 'fixed', 10.00, 60, 0.1, NULL, 3000, 0, true, false, NULL),
('BNB', 'fixed', 12.50, 90, 0.1, NULL, 2000, 0, true, false, 'High Yield'),

-- Solana (SOL)
('SOL', 'flexible', 6.00, 0, 0.1, NULL, 5000, 0, true, true, 'Fast Growing'),
('SOL', 'fixed', 8.50, 30, 0.1, NULL, 3000, 0, true, false, NULL),
('SOL', 'fixed', 11.00, 60, 0.1, NULL, 2000, 0, true, false, NULL),
('SOL', 'fixed', 13.50, 90, 0.1, NULL, 1500, 0, true, false, 'High Yield'),

-- USDT (Tether)
('USDT', 'flexible', 8.00, 0, 10, NULL, 1000000, 0, true, true, 'Stable Income'),
('USDT', 'fixed', 10.00, 30, 10, NULL, 500000, 0, true, false, NULL),
('USDT', 'fixed', 12.00, 60, 10, NULL, 300000, 0, true, false, NULL),
('USDT', 'fixed', 15.00, 90, 10, NULL, 200000, 0, true, false, 'Best Rate'),

-- USDC (USD Coin)
('USDC', 'flexible', 7.50, 0, 10, NULL, 800000, 0, true, true, 'Stable Income'),
('USDC', 'fixed', 9.50, 30, 10, NULL, 400000, 0, true, false, NULL),
('USDC', 'fixed', 11.50, 60, 10, NULL, 250000, 0, true, false, NULL),
('USDC', 'fixed', 14.00, 90, 10, NULL, 150000, 0, true, false, 'Best Rate'),

-- XRP (Ripple)
('XRP', 'flexible', 4.00, 0, 10, NULL, 100000, 0, true, false, NULL),
('XRP', 'fixed', 6.00, 30, 10, NULL, 50000, 0, true, false, NULL),
('XRP', 'fixed', 8.00, 60, 10, NULL, 30000, 0, true, false, NULL),
('XRP', 'fixed', 10.00, 90, 10, NULL, 20000, 0, true, false, 'High Yield'),

-- Cardano (ADA)
('ADA', 'flexible', 4.50, 0, 10, NULL, 80000, 0, true, false, NULL),
('ADA', 'fixed', 6.50, 30, 10, NULL, 40000, 0, true, false, NULL),
('ADA', 'fixed', 8.50, 60, 10, NULL, 25000, 0, true, false, NULL),
('ADA', 'fixed', 11.00, 90, 10, NULL, 15000, 0, true, false, 'High Yield'),

-- Dogecoin (DOGE)
('DOGE', 'flexible', 3.00, 0, 100, NULL, 500000, 0, true, false, 'Meme Coin'),
('DOGE', 'fixed', 5.00, 30, 100, NULL, 250000, 0, true, false, NULL),
('DOGE', 'fixed', 7.00, 60, 100, NULL, 150000, 0, true, false, NULL),
('DOGE', 'fixed', 9.00, 90, 100, NULL, 100000, 0, true, false, NULL),

-- Polkadot (DOT)
('DOT', 'flexible', 10.00, 0, 1, NULL, 30000, 0, true, true, 'High APY'),
('DOT', 'fixed', 12.50, 30, 1, NULL, 15000, 0, true, false, NULL),
('DOT', 'fixed', 15.00, 60, 1, NULL, 10000, 0, true, false, NULL),
('DOT', 'fixed', 18.00, 90, 1, NULL, 8000, 0, true, false, 'Premium'),

-- Polygon (MATIC)
('MATIC', 'flexible', 8.50, 0, 10, NULL, 100000, 0, true, true, 'L2 Leader'),
('MATIC', 'fixed', 11.00, 30, 10, NULL, 50000, 0, true, false, NULL),
('MATIC', 'fixed', 13.50, 60, 10, NULL, 30000, 0, true, false, NULL),
('MATIC', 'fixed', 16.00, 90, 10, NULL, 20000, 0, true, false, 'Premium'),

-- Litecoin (LTC)
('LTC', 'flexible', 3.50, 0, 0.1, NULL, 5000, 0, true, false, NULL),
('LTC', 'fixed', 5.50, 30, 0.1, NULL, 2500, 0, true, false, NULL),
('LTC', 'fixed', 7.50, 60, 0.1, NULL, 1500, 0, true, false, NULL),
('LTC', 'fixed', 9.50, 90, 0.1, NULL, 1000, 0, true, false, 'High Yield')
ON CONFLICT DO NOTHING;
