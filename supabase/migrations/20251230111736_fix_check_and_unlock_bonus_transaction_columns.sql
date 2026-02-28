/*
  # Fix check_and_unlock_bonus Transaction Columns

  ## Summary
  Fixes the check_and_unlock_bonus function to use the correct transaction
  table columns. The transactions table has 'details' (text) not 'metadata' (jsonb).

  ## Changes
  - Remove metadata column from transaction insert
  - Include all relevant info in the details text field
*/

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

  v_unlocked_amount := v_bonus.current_amount;
  v_realized_profits := v_bonus.realized_profits;

  UPDATE locked_bonuses
  SET
    is_unlocked = true,
    unlocked_at = now(),
    status = 'unlocked',
    updated_at = now()
  WHERE id = p_locked_bonus_id;

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

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details
  ) VALUES (
    v_bonus.user_id,
    'bonus',
    'USDT',
    v_unlocked_amount,
    'completed',
    'Locked Bonus Unlocked: ' || v_bonus.bonus_type_name || 
    '. Volume completed: $' || ROUND(v_bonus.bonus_trading_volume_completed, 2)::text ||
    ' / $' || ROUND(v_bonus.bonus_trading_volume_required, 2)::text ||
    '. Profits earned: $' || ROUND(v_realized_profits, 2)::text
  );

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
