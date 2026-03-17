/*
  # Add Geographic Restriction Checking to Bonus Awards

  1. Changes
    - Update award_user_bonus function to check user's country
    - Verify country against allowed_countries and excluded_countries lists
    - Reject bonus if user's country doesn't meet requirements

  2. Logic
    - If allowed_countries is set and user's country is not in the list, reject
    - If excluded_countries is set and user's country is in the list, reject
    - If both are null, allow (no geo-restrictions)
*/

CREATE OR REPLACE FUNCTION public.award_user_bonus(
  p_user_id uuid, 
  p_bonus_type_id uuid, 
  p_amount numeric, 
  p_awarded_by uuid, 
  p_notes text DEFAULT NULL::text, 
  p_expiry_days integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_bonus_id uuid;
  v_wallet_id uuid;
  v_bonus_type_name text;
  v_is_locked_bonus boolean;
  v_expires_at timestamptz;
  v_new_balance numeric;
  v_locked_bonus_id uuid;
  v_default_expiry integer;
  v_allowed_countries text[];
  v_excluded_countries text[];
  v_user_country text;
BEGIN
  -- Get bonus type info including geo-restrictions
  SELECT name, is_locked_bonus, expiry_days, allowed_countries, excluded_countries
  INTO v_bonus_type_name, v_is_locked_bonus, v_default_expiry, v_allowed_countries, v_excluded_countries
  FROM bonus_types 
  WHERE id = p_bonus_type_id AND is_active = true;

  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  -- Get user's country
  SELECT country INTO v_user_country
  FROM user_profiles
  WHERE id = p_user_id;

  -- Check allowed countries
  IF v_allowed_countries IS NOT NULL AND array_length(v_allowed_countries, 1) > 0 THEN
    IF v_user_country IS NULL OR NOT (v_user_country = ANY(v_allowed_countries)) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'This bonus is not available in your country'
      );
    END IF;
  END IF;

  -- Check excluded countries
  IF v_excluded_countries IS NOT NULL AND array_length(v_excluded_countries, 1) > 0 THEN
    IF v_user_country = ANY(v_excluded_countries) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'This bonus is not available in your country'
      );
    END IF;
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;

  -- Calculate expiry (use provided, else use bonus type default, else 7 days)
  IF p_expiry_days IS NOT NULL AND p_expiry_days > 0 THEN
    v_expires_at := now() + (p_expiry_days || ' days')::interval;
  ELSIF v_default_expiry IS NOT NULL AND v_default_expiry > 0 THEN
    v_expires_at := now() + (v_default_expiry || ' days')::interval;
  ELSE
    v_expires_at := now() + interval '7 days';
  END IF;

  -- Create bonus record
  INSERT INTO user_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    amount,
    status,
    awarded_by,
    awarded_at,
    expires_at,
    notes
  ) VALUES (
    p_user_id,
    p_bonus_type_id,
    v_bonus_type_name,
    p_amount,
    'active',
    p_awarded_by,
    now(),
    v_expires_at,
    p_notes
  ) RETURNING id INTO v_bonus_id;

  -- Handle locked bonus vs regular bonus
  IF v_is_locked_bonus = true THEN
    -- Insert into locked_bonuses table for futures trading
    INSERT INTO locked_bonuses (
      user_id,
      original_amount,
      current_amount,
      realized_profits,
      bonus_type_id,
      bonus_type_name,
      awarded_by,
      notes,
      status,
      expires_at,
      created_at,
      updated_at
    ) VALUES (
      p_user_id,
      p_amount,
      p_amount,
      0,
      p_bonus_type_id,
      v_bonus_type_name,
      p_awarded_by,
      COALESCE(p_notes, 'Locked trading bonus'),
      'active',
      v_expires_at,
      now(),
      now()
    ) RETURNING id INTO v_locked_bonus_id;

    v_new_balance := p_amount;

    -- Log transaction for locked bonus
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details
    ) VALUES (
      p_user_id,
      'locked_trading_bonus',
      'USDT',
      p_amount,
      'completed',
      'Locked Bonus: ' || v_bonus_type_name || ' (for futures trading only, profits withdrawable)'
    );
  ELSE
    -- Regular bonus - credit to main wallet
    SELECT id INTO v_wallet_id
    FROM wallets
    WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

    IF v_wallet_id IS NULL THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance)
      VALUES (p_user_id, 'USDT', 'main', 0)
      ON CONFLICT (user_id, currency, wallet_type) 
      DO UPDATE SET balance = wallets.balance
      RETURNING id INTO v_wallet_id;
    END IF;

    -- Credit the wallet
    UPDATE wallets
    SET 
      balance = balance + p_amount,
      updated_at = now()
    WHERE id = v_wallet_id
    RETURNING balance INTO v_new_balance;

    IF v_new_balance IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to update wallet balance'
      );
    END IF;

    -- Log transaction for regular bonus
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details
    ) VALUES (
      p_user_id,
      'reward',
      'USDT',
      p_amount,
      'completed',
      'Bonus: ' || v_bonus_type_name
    );
  END IF;

  -- Send notification
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    read,
    data
  ) VALUES (
    p_user_id,
    'Bonus Awarded!',
    CASE 
      WHEN v_is_locked_bonus THEN format('You have received a %s of $%s USDT! This is a locked trading bonus for futures trading - only profits can be withdrawn.', v_bonus_type_name, p_amount::text)
      ELSE format('You have received a %s bonus of $%s USDT!', v_bonus_type_name, p_amount::text)
    END,
    'account_update',
    false,
    jsonb_build_object(
      'bonus_id', v_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name,
      'is_locked', v_is_locked_bonus
    )
  );

  -- Log admin action
  PERFORM log_admin_action(
    p_awarded_by,
    'bonus_award',
    format('Awarded %s%s of $%s to user', 
      CASE WHEN v_is_locked_bonus THEN 'LOCKED ' ELSE '' END,
      v_bonus_type_name, 
      p_amount::text),
    p_user_id,
    jsonb_build_object(
      'bonus_type', v_bonus_type_name,
      'amount', p_amount,
      'bonus_id', v_bonus_id,
      'is_locked_bonus', v_is_locked_bonus,
      'locked_bonus_id', v_locked_bonus_id,
      'notes', COALESCE(p_notes, 'No notes'),
      'expiry_days', p_expiry_days,
      'expires_at', v_expires_at,
      'new_balance', v_new_balance
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bonus awarded successfully',
    'bonus_id', v_bonus_id,
    'is_locked_bonus', v_is_locked_bonus,
    'locked_bonus_id', v_locked_bonus_id,
    'new_balance', v_new_balance
  );
END;
$function$;
