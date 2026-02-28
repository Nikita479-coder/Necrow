/*
  # Rewrite Bonus Unlock Logic - Volume-Based Requirements

  ## Summary
  Completely rewrites the check_and_unlock_bonus function to use trading volume
  requirements instead of deposit and trade count requirements.

  ## Changes
  1. Drop old track_deposit_for_unlock and track_trade_for_unlock (already done)
  2. Rewrite check_and_unlock_bonus to check volume requirements only
  3. Auto-unlock when volume requirement is met
  4. Credit unlocked amount to futures margin wallet
  5. Send congratulations notification

  ## Unlock Requirements
  - Only requirement: bonus_trading_volume_completed >= bonus_trading_volume_required
  - No minimum deposit required
  - No minimum trade count required
  - Volume must come from positions using locked bonus funds
  - Positions must have been held for 60+ minutes to count

  ## Security
  - SECURITY DEFINER for system access
  - Only active bonuses can be unlocked
  - Bonus must not have expired
*/

-- Rewrite check_and_unlock_bonus function with volume-based logic
CREATE OR REPLACE FUNCTION check_and_unlock_bonus(p_locked_bonus_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlocked_amount numeric;
  v_realized_profits numeric;
BEGIN
  -- Get bonus details with lock
  SELECT * INTO v_bonus
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id
    AND status = 'active'
    AND COALESCE(is_unlocked, false) = false
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus not found, already unlocked, or expired'
    );
  END IF;

  -- Check if volume requirement is met
  IF v_bonus.bonus_trading_volume_completed < v_bonus.bonus_trading_volume_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'volume_required', v_bonus.bonus_trading_volume_required,
      'volume_completed', v_bonus.bonus_trading_volume_completed,
      'volume_remaining', v_bonus.bonus_trading_volume_required - v_bonus.bonus_trading_volume_completed,
      'percentage_complete', ROUND((v_bonus.bonus_trading_volume_completed / v_bonus.bonus_trading_volume_required * 100)::numeric, 2)
    );
  END IF;

  -- Requirements met! Unlock the bonus
  -- The unlocked amount is current_amount (original bonus amount minus losses)
  v_unlocked_amount := v_bonus.current_amount;
  v_realized_profits := v_bonus.realized_profits;

  -- Mark as unlocked
  UPDATE locked_bonuses
  SET
    is_unlocked = true,
    unlocked_at = now(),
    status = 'unlocked',
    updated_at = now()
  WHERE id = p_locked_bonus_id;

  -- Credit the unlocked bonus amount to user's futures margin wallet
  IF v_unlocked_amount > 0 THEN
    UPDATE futures_margin_wallets
    SET
      available_balance = available_balance + v_unlocked_amount,
      updated_at = now()
    WHERE user_id = v_bonus.user_id;

    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_bonus.user_id, v_unlocked_amount, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_unlocked_amount,
        updated_at = now();
    END IF;
  END IF;

  -- Record transaction for the unlocked bonus
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    metadata
  ) VALUES (
    v_bonus.user_id,
    'bonus',
    'USDT',
    v_unlocked_amount,
    'completed',
    'Locked Bonus Unlocked: ' || v_bonus.bonus_type_name || '. Trading volume requirement met.',
    jsonb_build_object(
      'locked_bonus_id', p_locked_bonus_id,
      'original_amount', v_bonus.original_amount,
      'unlocked_amount', v_unlocked_amount,
      'realized_profits', v_realized_profits,
      'volume_completed', v_bonus.bonus_trading_volume_completed,
      'volume_required', v_bonus.bonus_trading_volume_required
    )
  );

  -- Send congratulations notification
  INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
  VALUES (
    v_bonus.user_id,
    'reward',
    'Bonus Unlocked!',
    'Congratulations! You completed $' || ROUND(v_bonus.bonus_trading_volume_completed::numeric, 2)::text || 
    ' in trading volume and unlocked your ' || v_bonus.bonus_type_name || ' bonus of $' || 
    ROUND(v_unlocked_amount::numeric, 2)::text || ' USDT! This amount is now withdrawable from your futures wallet.' ||
    CASE 
      WHEN v_realized_profits > 0 
      THEN ' You also earned $' || ROUND(v_realized_profits::numeric, 2)::text || ' in profits!'
      ELSE ''
    END,
    false,
    jsonb_build_object(
      'locked_bonus_id', p_locked_bonus_id,
      'unlocked_amount', v_unlocked_amount,
      'realized_profits', v_realized_profits,
      'bonus_type', v_bonus.bonus_type_name,
      'redirect_url', '/wallet'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'unlocked', true,
    'amount', v_unlocked_amount,
    'realized_profits', v_realized_profits,
    'volume_completed', v_bonus.bonus_trading_volume_completed,
    'message', 'Bonus unlocked successfully!'
  );
END;
$$;

-- Create function to manually trigger unlock check for a user's bonuses
CREATE OR REPLACE FUNCTION check_user_bonuses_for_unlock(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlock_result jsonb;
  v_unlocked_count integer := 0;
  v_unlocked_total numeric := 0;
BEGIN
  -- Check all active locked bonuses for this user
  FOR v_bonus IN
    SELECT id, bonus_type_name, current_amount
    FROM locked_bonuses
    WHERE user_id = p_user_id
      AND status = 'active'
      AND COALESCE(is_unlocked, false) = false
      AND expires_at > now()
      AND bonus_trading_volume_completed >= bonus_trading_volume_required
    ORDER BY created_at ASC
  LOOP
    -- Attempt to unlock this bonus
    v_unlock_result := check_and_unlock_bonus(v_bonus.id);

    IF (v_unlock_result->>'unlocked')::boolean = true THEN
      v_unlocked_count := v_unlocked_count + 1;
      v_unlocked_total := v_unlocked_total + v_bonus.current_amount;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'bonuses_checked', v_unlocked_count,
    'total_unlocked', v_unlocked_total
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION check_and_unlock_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION check_user_bonuses_for_unlock(uuid) TO authenticated;
