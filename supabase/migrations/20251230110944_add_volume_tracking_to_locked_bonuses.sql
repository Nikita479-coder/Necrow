/*
  # Add Volume Tracking to Locked Bonuses

  ## Summary
  Updates locked bonus system to track trading volume requirements instead of deposit
  and trade count requirements. Implements 500x trading volume requirement with 60-minute
  minimum position duration for positions using locked bonus funds.

  ## Changes to locked_bonuses table
  - Add `bonus_trading_volume_required` (numeric) - defaults to 500x original bonus amount
  - Add `bonus_trading_volume_completed` (numeric) - tracks volume from locked bonus trades
  - Add `minimum_position_duration_minutes` (integer) - defaults to 60 minutes
  - Add `withdrawal_review_required` (boolean) - flags for potential abuse
  - Add `abuse_flags` (jsonb) - tracks suspicious patterns
  - Remove `deposits_required`, `deposits_completed`
  - Remove `trades_required`, `trades_completed`
  - Keep `is_unlocked` and `unlocked_at` for compatibility

  ## Changes to referral_stats table
  - Clarify that total_volume_30d and total_volume_all_time track REAL wallet trading only
  - These volumes determine VIP status and should never include locked bonus trading

  ## Security
  - Existing RLS policies remain unchanged
  - Admin can view and modify abuse flags
*/

-- Add new volume tracking columns to locked_bonuses
ALTER TABLE locked_bonuses
  ADD COLUMN IF NOT EXISTS bonus_trading_volume_required numeric(20,8) DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS bonus_trading_volume_completed numeric(20,8) DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS minimum_position_duration_minutes integer DEFAULT 60 NOT NULL,
  ADD COLUMN IF NOT EXISTS withdrawal_review_required boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS abuse_flags jsonb DEFAULT '[]'::jsonb NOT NULL;

-- Remove old deposit and trade count requirement columns
ALTER TABLE locked_bonuses
  DROP COLUMN IF EXISTS deposits_required,
  DROP COLUMN IF EXISTS deposits_completed,
  DROP COLUMN IF EXISTS trades_required,
  DROP COLUMN IF EXISTS trades_completed;

-- Drop old constraint if exists
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS locked_bonuses_unlock_progress_check;

-- Set bonus_trading_volume_required to 500x the original_amount for all existing bonuses
UPDATE locked_bonuses
SET bonus_trading_volume_required = original_amount * 500
WHERE bonus_trading_volume_required = 0;

-- Add check constraint to ensure volume required is positive
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS check_bonus_volume_required_positive;
  
ALTER TABLE locked_bonuses
  ADD CONSTRAINT check_bonus_volume_required_positive
  CHECK (bonus_trading_volume_required > 0);

-- Add check constraint to ensure completed volume is non-negative
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS check_bonus_volume_completed_non_negative;
  
ALTER TABLE locked_bonuses
  ADD CONSTRAINT check_bonus_volume_completed_non_negative
  CHECK (bonus_trading_volume_completed >= 0);

-- Add index for quick lookup of bonuses near completion
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_volume_progress
  ON locked_bonuses(user_id, status)
  WHERE status = 'active'
    AND bonus_trading_volume_completed >= (bonus_trading_volume_required * 0.9);

-- Drop old tracking functions that are no longer needed
DROP FUNCTION IF EXISTS track_deposit_for_unlock(uuid, numeric);
DROP FUNCTION IF EXISTS track_trade_for_unlock(uuid);

-- Create helper function to check if bonus is unlockable
CREATE OR REPLACE FUNCTION is_bonus_unlockable(p_locked_bonus_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_completed numeric;
  v_required numeric;
  v_status text;
BEGIN
  SELECT
    bonus_trading_volume_completed,
    bonus_trading_volume_required,
    status
  INTO v_completed, v_required, v_status
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id;

  -- Check if bonus exists and is active
  IF v_status IS NULL OR v_status != 'active' THEN
    RETURN false;
  END IF;

  -- Check if trading volume requirement is met
  RETURN v_completed >= v_required;
END;
$$;

-- Drop the old get_bonus_unlock_progress function and recreate with new signature
DROP FUNCTION IF EXISTS get_bonus_unlock_progress(uuid);

-- Create function to get all unlock progress for a user
CREATE OR REPLACE FUNCTION get_bonus_unlock_progress(p_user_id uuid)
RETURNS TABLE (
  locked_bonus_id uuid,
  bonus_type_name text,
  original_amount numeric,
  current_amount numeric,
  realized_profits numeric,
  volume_required numeric,
  volume_completed numeric,
  volume_percentage numeric,
  minimum_duration_minutes integer,
  is_unlockable boolean,
  is_unlocked boolean,
  status text,
  expires_at timestamptz,
  days_remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    lb.id,
    lb.bonus_type_name,
    lb.original_amount,
    lb.current_amount,
    lb.realized_profits,
    lb.bonus_trading_volume_required,
    lb.bonus_trading_volume_completed,
    CASE
      WHEN lb.bonus_trading_volume_required > 0
      THEN ROUND((lb.bonus_trading_volume_completed / lb.bonus_trading_volume_required * 100)::numeric, 2)
      ELSE 0
    END as volume_percentage,
    lb.minimum_position_duration_minutes,
    is_bonus_unlockable(lb.id) as is_unlockable,
    COALESCE(lb.is_unlocked, false) as is_unlocked,
    lb.status,
    lb.expires_at,
    GREATEST(0, EXTRACT(DAY FROM (lb.expires_at - now()))::integer) as days_remaining
  FROM locked_bonuses lb
  WHERE lb.user_id = p_user_id
  ORDER BY lb.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_bonus_unlockable(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bonus_unlock_progress(uuid) TO authenticated;

-- Add comment to referral_stats table clarifying volume tracking
COMMENT ON COLUMN referral_stats.total_volume_30d IS 'Tracks REAL wallet trading volume only (not locked bonus volume). Used for VIP tier calculation.';
COMMENT ON COLUMN referral_stats.total_volume_all_time IS 'Tracks REAL wallet trading volume only (not locked bonus volume). Used for VIP tier calculation and affiliate programs.';
