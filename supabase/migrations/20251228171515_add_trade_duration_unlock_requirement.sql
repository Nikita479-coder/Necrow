/*
  # Add Trade Duration Unlock Requirement

  ## Summary
  Enhances locked bonus unlock requirements to ensure quality trading activity.
  Users must now meet ALL of the following requirements:
  - Deposit at least $100 USD
  - Complete at least 10 trades
  - Last 5 trades must each be open for more than 60 minutes

  ## Changes
  1. Create function to validate trade duration requirements
  2. Update check_and_unlock_bonus() to include duration validation
  3. Update get_bonus_unlock_progress() to show duration progress

  ## Logic
  - Counts completed futures positions for the user
  - Checks the 5 most recent closed positions
  - Each must have been open for at least 60 minutes
  - If user has fewer than 5 trades, all existing trades must meet the duration requirement

  ## Security
  - Uses existing RLS policies
  - Only validates completed trades
*/

-- Function to check if last trades meet duration requirement
CREATE OR REPLACE FUNCTION check_trade_duration_requirement(
  p_user_id uuid,
  p_required_count integer DEFAULT 5,
  p_minimum_duration_minutes integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_total_trades integer;
  v_trades_checked integer;
  v_trades_meeting_duration integer;
  v_trade record;
  v_duration_minutes numeric;
BEGIN
  -- Count total completed trades
  SELECT COUNT(*) INTO v_total_trades
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'closed'
    AND closed_at IS NOT NULL;

  -- If user has fewer than required count, check all available trades
  v_trades_checked := LEAST(v_total_trades, p_required_count);

  -- If no trades, requirement not met
  IF v_trades_checked = 0 THEN
    RETURN jsonb_build_object(
      'requirement_met', false,
      'total_trades', 0,
      'trades_checked', 0,
      'trades_meeting_duration', 0,
      'trades_needed', p_required_count,
      'minimum_duration_minutes', p_minimum_duration_minutes
    );
  END IF;

  -- Check the most recent trades for duration
  v_trades_meeting_duration := 0;

  FOR v_trade IN
    SELECT
      position_id,
      pair,
      opened_at,
      closed_at,
      EXTRACT(EPOCH FROM (closed_at - opened_at)) / 60 as duration_minutes
    FROM futures_positions
    WHERE user_id = p_user_id
      AND status = 'closed'
      AND closed_at IS NOT NULL
      AND opened_at IS NOT NULL
    ORDER BY closed_at DESC
    LIMIT p_required_count
  LOOP
    v_duration_minutes := v_trade.duration_minutes;

    -- Check if this trade meets the minimum duration
    IF v_duration_minutes >= p_minimum_duration_minutes THEN
      v_trades_meeting_duration := v_trades_meeting_duration + 1;
    END IF;
  END LOOP;

  -- Requirement is met if all checked trades meet the duration
  RETURN jsonb_build_object(
    'requirement_met', (v_trades_meeting_duration >= v_trades_checked),
    'total_trades', v_total_trades,
    'trades_checked', v_trades_checked,
    'trades_meeting_duration', v_trades_meeting_duration,
    'trades_needed', p_required_count,
    'minimum_duration_minutes', p_minimum_duration_minutes
  );
END;
$$;

-- Update check_and_unlock_bonus to include trade duration validation
CREATE OR REPLACE FUNCTION check_and_unlock_bonus(p_locked_bonus_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlocked_amount numeric;
  v_duration_check jsonb;
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

  -- Check deposit requirement
  IF v_bonus.deposits_completed < v_bonus.deposits_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'deposits_remaining', v_bonus.deposits_required - v_bonus.deposits_completed,
      'trades_remaining', GREATEST(0, v_bonus.trades_required - v_bonus.trades_completed),
      'message', 'Deposit requirement not met'
    );
  END IF;

  -- Check trade count requirement
  IF v_bonus.trades_completed < v_bonus.trades_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'deposits_remaining', 0,
      'trades_remaining', v_bonus.trades_required - v_bonus.trades_completed,
      'message', 'Trade count requirement not met'
    );
  END IF;

  -- Check trade duration requirement
  v_duration_check := check_trade_duration_requirement(v_bonus.user_id, 5, 60);

  IF (v_duration_check->>'requirement_met')::boolean = false THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'deposits_remaining', 0,
      'trades_remaining', 0,
      'duration_requirement', v_duration_check,
      'message', 'Last ' || (v_duration_check->>'trades_checked')::text ||
                 ' trade(s) must each be open for at least 60 minutes. Currently ' ||
                 (v_duration_check->>'trades_meeting_duration')::text || ' of ' ||
                 (v_duration_check->>'trades_checked')::text || ' trades meet this requirement.'
    );
  END IF;

  -- All requirements met! Unlock the bonus
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
      available_balance = futures_margin_wallets.available_balance + v_unlocked_amount,
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
      'trades_completed', v_bonus.trades_completed,
      'duration_check', v_duration_check
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

-- Drop and recreate get_bonus_unlock_progress with new signature
DROP FUNCTION IF EXISTS get_bonus_unlock_progress(uuid);

CREATE FUNCTION get_bonus_unlock_progress(p_user_id uuid)
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
  duration_requirement jsonb,
  is_unlocked boolean,
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
    lb.deposits_required,
    lb.deposits_completed,
    GREATEST(0, lb.deposits_required - lb.deposits_completed) as deposits_remaining,
    lb.trades_required,
    lb.trades_completed,
    GREATEST(0, lb.trades_required - lb.trades_completed) as trades_remaining,
    check_trade_duration_requirement(p_user_id, 5, 60) as duration_requirement,
    lb.is_unlocked,
    lb.expires_at,
    GREATEST(0, EXTRACT(DAY FROM (lb.expires_at - now()))::integer) as days_remaining
  FROM locked_bonuses lb
  WHERE lb.user_id = p_user_id
    AND lb.status IN ('active', 'unlocked')
  ORDER BY lb.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_trade_duration_requirement(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION check_and_unlock_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bonus_unlock_progress(uuid) TO authenticated;