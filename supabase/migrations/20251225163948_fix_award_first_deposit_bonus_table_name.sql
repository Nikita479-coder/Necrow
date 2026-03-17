/*
  # Fix Award First Deposit Bonus Function

  ## Summary
  Fixes the award_first_deposit_bonus function to use the correct table name
  `locked_bonuses` instead of `user_locked_bonuses`, and correct notification column.

  ## Changes
  - Changed table reference from user_locked_bonuses to locked_bonuses
  - Changed notifications.notification_type to notifications.type
  - Added bonus_type_name column which exists in locked_bonuses table

  ## Impact
  - First deposit bonus awarding will now work correctly
  - Deposit completion process will succeed
*/

CREATE OR REPLACE FUNCTION award_first_deposit_bonus(p_user_id uuid, p_deposit_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_bonus_amount numeric;
  v_locked_bonus_id uuid;
BEGIN
  SELECT * INTO v_tracking
  FROM signup_bonus_tracking
  WHERE user_id = p_user_id;

  IF v_tracking IS NULL THEN
    INSERT INTO signup_bonus_tracking (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_tracking;
  END IF;

  IF v_tracking.first_deposit_bonus_awarded THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'First deposit bonus has already been awarded'
    );
  END IF;

  SELECT * INTO v_bonus_type
  FROM bonus_types
  WHERE name = 'First Deposit Match Bonus'
  AND is_active = true;

  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'First deposit bonus type not found or inactive'
    );
  END IF;

  v_bonus_amount := LEAST(p_deposit_amount, v_bonus_type.default_amount);

  INSERT INTO locked_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    original_amount,
    current_amount,
    status,
    expires_at
  ) VALUES (
    p_user_id,
    v_bonus_type.id,
    v_bonus_type.name,
    v_bonus_amount,
    v_bonus_amount,
    'active',
    now() + (COALESCE(v_bonus_type.expiry_days, 7) || ' days')::interval
  )
  RETURNING id INTO v_locked_bonus_id;

  UPDATE signup_bonus_tracking
  SET 
    first_deposit_bonus_awarded = true,
    first_deposit_bonus_awarded_at = now(),
    first_deposit_amount = p_deposit_amount,
    first_deposit_bonus_amount = v_bonus_amount
  WHERE user_id = p_user_id;

  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    p_user_id,
    'bonus',
    'First Deposit Bonus Awarded!',
    'Congratulations! You received $' || v_bonus_amount || ' locked trading credit (100% match). Valid for 7 days for futures trading. Only profits can be withdrawn.',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'deposit_amount', p_deposit_amount,
    'bonus_amount', v_bonus_amount,
    'locked_bonus_id', v_locked_bonus_id,
    'expires_at', now() + (COALESCE(v_bonus_type.expiry_days, 7) || ' days')::interval
  );
END;
$$;
