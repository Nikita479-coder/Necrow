/*
  # Add Recruitment Boost Schema Columns

  Adds columns needed for the rolling 30-day recruitment boost system across three tables.

  ## Changes

  ### 1. `exclusive_affiliates` table
    - `is_boost_eligible` (boolean, default true) - Admin toggle to enable/disable boost for this affiliate
    - `boost_override_multiplier` (numeric, nullable) - Admin override multiplier (when set, replaces calculated boost)

  ### 2. `exclusive_affiliate_commissions` table
    - `base_commission_amount` (numeric, default 0) - Commission amount before boost was applied
    - `boost_multiplier` (numeric, default 1.0) - The multiplier that was applied at time of calculation
    - `boost_tier` (text, nullable) - Human-readable tier label at time of calculation (e.g. "11-20 FTDs +35%")

  ### 3. `exclusive_affiliate_network_stats` table
    - `ftd_count_30d` (integer, default 0) - Cached rolling 30-day Level-1 FTD count
    - `current_boost_tier` (text, default 'none') - Cached current tier label
    - `current_boost_multiplier` (numeric, default 1.0) - Cached current multiplier
    - `boost_updated_at` (timestamptz, nullable) - When cached values were last refreshed

  ## Notes
    - The `commission_amount` column in `exclusive_affiliate_commissions` continues to hold the final (boosted) amount
    - Cached boost columns on `network_stats` are for display only; live calculation is used for actual commission math
    - Existing commission records get base_commission_amount = commission_amount and boost_multiplier = 1.0 (no boost)
*/

-- 1. Add boost admin controls to exclusive_affiliates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliates' AND column_name = 'is_boost_eligible'
  ) THEN
    ALTER TABLE exclusive_affiliates ADD COLUMN is_boost_eligible boolean DEFAULT true;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliates' AND column_name = 'boost_override_multiplier'
  ) THEN
    ALTER TABLE exclusive_affiliates ADD COLUMN boost_override_multiplier numeric DEFAULT NULL;
  END IF;
END $$;

-- 2. Add boost audit columns to exclusive_affiliate_commissions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_commissions' AND column_name = 'base_commission_amount'
  ) THEN
    ALTER TABLE exclusive_affiliate_commissions ADD COLUMN base_commission_amount numeric NOT NULL DEFAULT 0;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_commissions' AND column_name = 'boost_multiplier'
  ) THEN
    ALTER TABLE exclusive_affiliate_commissions ADD COLUMN boost_multiplier numeric NOT NULL DEFAULT 1.0;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_commissions' AND column_name = 'boost_tier'
  ) THEN
    ALTER TABLE exclusive_affiliate_commissions ADD COLUMN boost_tier text DEFAULT NULL;
  END IF;
END $$;

-- 3. Add cached boost display columns to exclusive_affiliate_network_stats
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_network_stats' AND column_name = 'ftd_count_30d'
  ) THEN
    ALTER TABLE exclusive_affiliate_network_stats ADD COLUMN ftd_count_30d integer DEFAULT 0;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_network_stats' AND column_name = 'current_boost_tier'
  ) THEN
    ALTER TABLE exclusive_affiliate_network_stats ADD COLUMN current_boost_tier text DEFAULT 'none';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_network_stats' AND column_name = 'current_boost_multiplier'
  ) THEN
    ALTER TABLE exclusive_affiliate_network_stats ADD COLUMN current_boost_multiplier numeric DEFAULT 1.0;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'exclusive_affiliate_network_stats' AND column_name = 'boost_updated_at'
  ) THEN
    ALTER TABLE exclusive_affiliate_network_stats ADD COLUMN boost_updated_at timestamptz DEFAULT NULL;
  END IF;
END $$;

-- 4. Backfill existing commission records: base_commission_amount = commission_amount (no boost was applied)
UPDATE exclusive_affiliate_commissions
SET base_commission_amount = commission_amount
WHERE base_commission_amount = 0 AND commission_amount > 0;
