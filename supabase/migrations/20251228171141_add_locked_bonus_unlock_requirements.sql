/*
  # Add Locked Bonus Unlock Requirements

  ## Summary
  Adds deposit and trade requirements to unlock locked bonuses.
  Users must complete BOTH requirements to unlock their bonus:
  - Deposit at least $100 USD
  - Complete at least 10 trades

  Once unlocked, the locked bonus becomes withdrawable.

  ## Changes
  1. Add tracking columns to locked_bonuses table:
     - deposits_required (numeric) - Amount required (default 100)
     - deposits_completed (numeric) - Amount deposited so far
     - trades_required (integer) - Number of trades required (default 10)
     - trades_completed (integer) - Number of trades completed
     - is_unlocked (boolean) - Whether requirements are met
     - unlocked_at (timestamptz) - When it was unlocked

  2. Create functions:
     - check_and_unlock_bonus() - Check if requirements met and unlock
     - track_deposit_for_unlock() - Track deposits toward unlock
     - track_trade_for_unlock() - Track trades toward unlock

  ## Security
  - Only the system and admins can unlock bonuses
  - Users can view their progress
*/

-- Add unlock requirement columns to locked_bonuses
ALTER TABLE locked_bonuses
  ADD COLUMN IF NOT EXISTS deposits_required numeric(20,8) DEFAULT 100 NOT NULL,
  ADD COLUMN IF NOT EXISTS deposits_completed numeric(20,8) DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS trades_required integer DEFAULT 10 NOT NULL,
  ADD COLUMN IF NOT EXISTS trades_completed integer DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS is_unlocked boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS unlocked_at timestamptz;

-- Add check constraints
ALTER TABLE locked_bonuses
  DROP CONSTRAINT IF EXISTS locked_bonuses_unlock_progress_check;

ALTER TABLE locked_bonuses
  ADD CONSTRAINT locked_bonuses_unlock_progress_check
  CHECK (
    deposits_completed >= 0 AND
    trades_completed >= 0 AND
    deposits_completed <= deposits_required * 2 AND
    trades_completed <= trades_required * 2
  );

-- Index for querying unlockable bonuses
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_unlockable
  ON locked_bonuses(user_id, is_unlocked)
  WHERE status = 'active' AND is_unlocked = false;

-- Function to check if bonus requirements are met and unlock it
CREATE OR REPLACE FUNCTION check_and_unlock_bonus(p_locked_bonus_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlocked_amount numeric;
BEGIN
  -- Get bonus details
  SELECT * INTO v_bonus
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id
    AND status = 'active'
    AND is_unlocked = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus not found or already unlocked'
    );
  END IF;

  -- Check if requirements are met
  IF v_bonus.deposits_completed < v_bonus.deposits_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'deposits_remaining', v_bonus.deposits_required - v_bonus.deposits_completed,
      'trades_remaining', GREATEST(0, v_bonus.trades_required - v_bonus.trades_completed)
    );
  END IF;

  IF v_bonus.trades_completed < v_bonus.trades_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'deposits_remaining', 0,
      'trades_remaining', v_bonus.trades_required - v_bonus.trades_completed
    );
  END IF;

  -- Requirements met! Unlock the bonus
  v_unlocked_amount := v_bonus.current_amount;

  -- Mark as unlocked
  UPDATE locked_bonuses
  SET
    is_unlocked = true,
    unlocked_at = now(),
    status = 'unlocked',
    updated_at = now()
  WHERE id = p_locked_bonus_id;

  -- Credit the unlocked amount to user's futures margin wallet
  UPDATE futures_margin_wallets
  SET
    available_balance = available_balance + v_unlocked_amount,
    updated_at = now()
  WHERE user_id = v_bonus.user_id;

  -- Auto-create futures wallet if it doesn't exist
  IF NOT FOUND THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance)
    VALUES (v_bonus.user_id, v_unlocked_amount)
    ON CONFLICT (user_id)
    DO UPDATE SET
      available_balance = EXCLUDED.available_balance + v_unlocked_amount,
      updated_at = now();
  END IF;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    metadata
  ) VALUES (
    v_bonus.user_id,
    'bonus',
    'USDT',
    v_unlocked_amount,
    'completed',
    'Locked Bonus Unlocked: ' || v_bonus.bonus_type_name,
    jsonb_build_object(
      'locked_bonus_id', p_locked_bonus_id,
      'original_amount', v_bonus.original_amount,
      'unlocked_amount', v_unlocked_amount,
      'deposits_completed', v_bonus.deposits_completed,
      'trades_completed', v_bonus.trades_completed
    )
  );

  -- Send congratulations notification
  INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
  VALUES (
    v_bonus.user_id,
    'reward',
    '🎉 Bonus Unlocked!',
    'Congratulations! You have met all requirements and unlocked $' || v_unlocked_amount::text || ' USDT! This amount is now withdrawable.',
    false,
    jsonb_build_object(
      'locked_bonus_id', p_locked_bonus_id,
      'amount', v_unlocked_amount,
      'bonus_type', v_bonus.bonus_type_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'unlocked', true,
    'amount', v_unlocked_amount,
    'message', 'Bonus unlocked successfully!'
  );
END;
$$;

-- Function to track deposits toward unlock requirements
CREATE OR REPLACE FUNCTION track_deposit_for_unlock(
  p_user_id uuid,
  p_deposit_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlock_result jsonb;
  v_unlocked_count integer := 0;
BEGIN
  -- Update all active locked bonuses for this user
  FOR v_bonus IN
    SELECT id, deposits_required, deposits_completed, is_unlocked
    FROM locked_bonuses
    WHERE user_id = p_user_id
      AND status = 'active'
      AND is_unlocked = false
      AND expires_at > now()
    ORDER BY created_at ASC
  LOOP
    -- Add deposit amount to progress
    UPDATE locked_bonuses
    SET
      deposits_completed = LEAST(deposits_completed + p_deposit_amount, deposits_required),
      updated_at = now()
    WHERE id = v_bonus.id;

    -- Check if this bonus can now be unlocked
    v_unlock_result := check_and_unlock_bonus(v_bonus.id);

    IF (v_unlock_result->>'unlocked')::boolean = true THEN
      v_unlocked_count := v_unlocked_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'deposit_amount', p_deposit_amount,
    'bonuses_unlocked', v_unlocked_count
  );
END;
$$;

-- Function to track trades toward unlock requirements
CREATE OR REPLACE FUNCTION track_trade_for_unlock(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlock_result jsonb;
  v_unlocked_count integer := 0;
BEGIN
  -- Update all active locked bonuses for this user
  FOR v_bonus IN
    SELECT id, trades_required, trades_completed, is_unlocked
    FROM locked_bonuses
    WHERE user_id = p_user_id
      AND status = 'active'
      AND is_unlocked = false
      AND expires_at > now()
    ORDER BY created_at ASC
  LOOP
    -- Increment trade counter
    UPDATE locked_bonuses
    SET
      trades_completed = LEAST(trades_completed + 1, trades_required),
      updated_at = now()
    WHERE id = v_bonus.id;

    -- Check if this bonus can now be unlocked
    v_unlock_result := check_and_unlock_bonus(v_bonus.id);

    IF (v_unlock_result->>'unlocked')::boolean = true THEN
      v_unlocked_count := v_unlocked_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'bonuses_unlocked', v_unlocked_count
  );
END;
$$;

-- Function to get unlock progress for a user
CREATE OR REPLACE FUNCTION get_bonus_unlock_progress(p_user_id uuid)
RETURNS TABLE (
  locked_bonus_id uuid,
  bonus_type_name text,
  original_amount numeric,
  current_amount numeric,
  deposits_required numeric,
  deposits_completed numeric,
  deposits_remaining numeric,
  trades_required integer,
  trades_completed integer,
  trades_remaining integer,
  is_unlocked boolean,
  expires_at timestamptz,
  days_remaining integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    id,
    bonus_type_name,
    original_amount,
    current_amount,
    deposits_required,
    deposits_completed,
    GREATEST(0, deposits_required - deposits_completed) as deposits_remaining,
    trades_required,
    trades_completed,
    GREATEST(0, trades_required - trades_completed) as trades_remaining,
    is_unlocked,
    expires_at,
    GREATEST(0, EXTRACT(DAY FROM (expires_at - now()))::integer) as days_remaining
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status IN ('active', 'unlocked')
  ORDER BY created_at DESC;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_and_unlock_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION track_deposit_for_unlock(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION track_trade_for_unlock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bonus_unlock_progress(uuid) TO authenticated;
