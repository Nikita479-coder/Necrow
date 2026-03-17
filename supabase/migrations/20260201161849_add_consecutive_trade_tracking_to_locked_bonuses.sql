/*
  # Add Consecutive Trade Tracking to Locked Bonuses

  ## Summary
  Adds columns to support the new combined KYC + TrustPilot bonus that requires
  users to trade for 30 consecutive days with minimum 2 qualifying trades per day,
  where each trade must last at least 15 minutes.

  ## New Columns on locked_bonuses
  - `consecutive_trading_days_required` (integer) - Days of consecutive trading required (30 for new bonus)
  - `current_consecutive_days` (integer) - Current streak count
  - `daily_trades_required` (integer) - Minimum trades per day to count as a qualifying day (2)
  - `daily_trade_duration_minutes` (integer) - Minimum duration for a trade to count (15 minutes)
  - `daily_trade_count_today` (integer) - Trades completed today meeting duration requirement
  - `last_qualifying_trade_date` (date) - Last date user met daily requirement

  ## Behavior
  - Existing bonuses with NULL in these columns use old rules (volume-only unlock)
  - New combined bonus requires BOTH volume AND consecutive day requirements
  - If user misses a day, consecutive streak resets to 0

  ## Security
  - Existing RLS policies remain unchanged
*/

-- Add consecutive trade tracking columns
ALTER TABLE locked_bonuses
  ADD COLUMN IF NOT EXISTS consecutive_trading_days_required integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS current_consecutive_days integer DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS daily_trades_required integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS daily_trade_duration_minutes integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS daily_trade_count_today integer DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS last_qualifying_trade_date date DEFAULT NULL;

-- Add check constraints
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS check_consecutive_days_non_negative;

ALTER TABLE locked_bonuses
  ADD CONSTRAINT check_consecutive_days_non_negative
  CHECK (current_consecutive_days >= 0);

ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS check_daily_trade_count_non_negative;

ALTER TABLE locked_bonuses
  ADD CONSTRAINT check_daily_trade_count_non_negative
  CHECK (daily_trade_count_today >= 0);

-- Index for quick lookup of bonuses with consecutive day requirements
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_consecutive_tracking
  ON locked_bonuses(user_id, status)
  WHERE status = 'active'
    AND consecutive_trading_days_required IS NOT NULL;

-- Update is_bonus_unlockable to check consecutive day requirements too
CREATE OR REPLACE FUNCTION is_bonus_unlockable(p_locked_bonus_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_volume_completed numeric;
  v_volume_required numeric;
  v_consecutive_required integer;
  v_consecutive_current integer;
  v_status text;
BEGIN
  SELECT
    bonus_trading_volume_completed,
    bonus_trading_volume_required,
    consecutive_trading_days_required,
    current_consecutive_days,
    status
  INTO v_volume_completed, v_volume_required, v_consecutive_required, v_consecutive_current, v_status
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id;

  -- Check if bonus exists and is active
  IF v_status IS NULL OR v_status != 'active' THEN
    RETURN false;
  END IF;

  -- Check if trading volume requirement is met
  IF v_volume_completed < v_volume_required THEN
    RETURN false;
  END IF;

  -- Check if consecutive days requirement exists and is met
  IF v_consecutive_required IS NOT NULL AND v_consecutive_current < v_consecutive_required THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_bonus_unlockable(uuid) TO authenticated;
