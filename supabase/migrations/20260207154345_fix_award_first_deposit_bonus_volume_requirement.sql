/*
  # Fix award_first_deposit_bonus Missing Volume Requirement

  ## Problem
  The award_first_deposit_bonus function was directly inserting into locked_bonuses 
  without setting bonus_trading_volume_required, causing it to default to 0.
  This allowed users to receive "Bonus Ready to Unlock!" notifications after ANY trade.

  ## Solution
  1. Update the function to properly set:
     - bonus_trading_volume_required = amount * 500
     - bonus_trading_volume_completed = 0
     - minimum_position_duration_minutes = 10
     - Other required fields for proper bonus tracking

  ## Changes
  - Rewrites award_first_deposit_bonus to include all required volume tracking fields
*/

CREATE OR REPLACE FUNCTION public.award_first_deposit_bonus(p_user_id uuid, p_deposit_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_bonus_amount numeric;
  v_locked_bonus_id uuid;
  v_volume_required numeric;
  v_expires_at timestamptz;
  v_expiry_days integer;
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
  v_volume_required := v_bonus_amount * 500;
  v_expiry_days := COALESCE(v_bonus_type.expiry_days, 7);
  v_expires_at := now() + (v_expiry_days || ' days')::interval;

  INSERT INTO locked_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    original_amount,
    current_amount,
    realized_profits,
    status,
    expires_at,
    bonus_trading_volume_required,
    bonus_trading_volume_completed,
    minimum_position_duration_minutes,
    withdrawal_review_required,
    abuse_flags
  ) VALUES (
    p_user_id,
    v_bonus_type.id,
    v_bonus_type.name,
    v_bonus_amount,
    v_bonus_amount,
    0,
    'active',
    v_expires_at,
    v_volume_required,
    0,
    10,
    false,
    '[]'::jsonb
  )
  RETURNING id INTO v_locked_bonus_id;

  UPDATE signup_bonus_tracking
  SET 
    first_deposit_bonus_awarded = true,
    first_deposit_bonus_awarded_at = now(),
    first_deposit_amount = p_deposit_amount,
    first_deposit_bonus_amount = v_bonus_amount
  WHERE user_id = p_user_id;

  INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
  VALUES (
    p_user_id,
    'bonus',
    'First Deposit Bonus Awarded!',
    'Congratulations! You received $' || ROUND(v_bonus_amount, 2) || ' USDT locked bonus! ' ||
    'Use it for futures trading - profits are yours to keep! ' ||
    'To unlock: Complete $' || ROUND(v_volume_required, 2) || ' in trading volume. ' ||
    'Positions must be held for at least 10 minutes. Expires in ' || v_expiry_days || ' days.',
    false,
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'amount', v_bonus_amount,
      'volume_required', v_volume_required,
      'expires_at', v_expires_at
    ),
    '/wallet'
  );

  RETURN jsonb_build_object(
    'success', true,
    'deposit_amount', p_deposit_amount,
    'bonus_amount', v_bonus_amount,
    'locked_bonus_id', v_locked_bonus_id,
    'volume_required', v_volume_required,
    'expires_at', v_expires_at
  );
END;
$function$;
