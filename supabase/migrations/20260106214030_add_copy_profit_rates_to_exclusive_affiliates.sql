/*
  # Add Copy Trading Profit Rates to Exclusive Affiliates

  ## Overview
  Adds support for multi-tier commission on copy trading profits for VIP affiliates.
  When a referred user makes profitable copy trades (real only, not mock), 
  the platform pays commissions from platform funds to the upline affiliates.

  ## Changes
  1. `exclusive_affiliates` table:
     - Add `copy_profit_rates` JSONB column with default rates: 10%, 5%, 4%, 3%, 2% for levels 1-5

  2. `exclusive_affiliate_balances` table:
     - Add `copy_profit_earned` column to track earnings from this source

  3. `exclusive_affiliate_commissions` table:
     - Update check constraint to allow 'copy_profit' commission type

  ## Security
  - No new RLS policies needed (existing policies cover new columns)
  - Copy profit earnings paid from platform funds, not deducted from users
*/

-- Add copy_profit_rates column to exclusive_affiliates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliates' AND column_name = 'copy_profit_rates'
  ) THEN
    ALTER TABLE exclusive_affiliates 
    ADD COLUMN copy_profit_rates JSONB NOT NULL DEFAULT '{"level_1": 10, "level_2": 5, "level_3": 4, "level_4": 3, "level_5": 2}';
  END IF;
END $$;

-- Add copy_profit_earned column to exclusive_affiliate_balances
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_balances' AND column_name = 'copy_profit_earned'
  ) THEN
    ALTER TABLE exclusive_affiliate_balances 
    ADD COLUMN copy_profit_earned NUMERIC NOT NULL DEFAULT 0 CHECK (copy_profit_earned >= 0);
  END IF;
END $$;

-- Update commission_type check constraint to include 'copy_profit'
DO $$
BEGIN
  ALTER TABLE exclusive_affiliate_commissions 
    DROP CONSTRAINT IF EXISTS exclusive_affiliate_commissions_commission_type_check;
  
  ALTER TABLE exclusive_affiliate_commissions 
    ADD CONSTRAINT exclusive_affiliate_commissions_commission_type_check 
    CHECK (commission_type IN ('deposit', 'trading_fee', 'copy_profit'));
END $$;

COMMENT ON COLUMN exclusive_affiliates.copy_profit_rates IS 
  'Multi-tier commission rates for copy trading profits. Default: Level 1: 10%, Level 2: 5%, Level 3: 4%, Level 4: 3%, Level 5: 2%';

COMMENT ON COLUMN exclusive_affiliate_balances.copy_profit_earned IS 
  'Total earnings from commissions on referrals copy trading profits';
