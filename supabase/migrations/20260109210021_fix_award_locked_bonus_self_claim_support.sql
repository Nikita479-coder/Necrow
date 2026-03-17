/*
  # Fix award_locked_bonus to Support Self-Claims

  ## Problem
  - The awarded_by column in user_bonuses has a NOT NULL constraint
  - When users claim their own rewards, the frontend passes null for p_awarded_by
  - This causes "null value in column awarded_by violates not-null constraint" error

  ## Solution
  - Make p_awarded_by nullable and default it to the user's own ID when null
  - This allows users to self-claim rewards (marked as self-awarded)
  - Admin-awarded bonuses still show who awarded them
  - Only log to admin_activity_logs if actually awarded by an admin (not self-claimed)

  ## Impact
  - Users can successfully claim task rewards
  - Self-claimed rewards are marked with the user's own ID
  - Admin-awarded bonuses still track who awarded them
*/

CREATE OR REPLACE FUNCTION award_locked_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_expiry_days integer DEFAULT 7
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locked_bonus_id uuid;
  v_user_bonus_id uuid;
  v_bonus_type_name text;
  v_expires_at timestamptz;
  v_username text;
  v_volume_required numeric;
  v_effective_awarded_by uuid;
BEGIN
  -- If awarded_by is NULL, the user is claiming it themselves
  v_effective_awarded_by := COALESCE(p_awarded_by, p_user_id);

  SELECT name INTO v_bonus_type_name
  FROM bonus_types
  WHERE id = p_bonus_type_id AND is_active = true;

  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;

  IF p_expiry_days IS NULL OR p_expiry_days < 1 THEN
    p_expiry_days := 7;
  END IF;

  v_expires_at := now() + (p_expiry_days || ' days')::interval;
  v_volume_required := p_amount * 500;

  SELECT username INTO v_username
  FROM user_profiles
  WHERE id = p_user_id;

  INSERT INTO locked_bonuses (
    user_id, original_amount, current_amount, realized_profits,
    bonus_type_id, bonus_type_name, awarded_by, notes, status, expires_at,
    bonus_trading_volume_required, bonus_trading_volume_completed,
    minimum_position_duration_minutes, withdrawal_review_required, abuse_flags
  ) VALUES (
    p_user_id, p_amount, p_amount, 0,
    p_bonus_type_id, v_bonus_type_name, v_effective_awarded_by, p_notes, 'active', v_expires_at,
    v_volume_required, 0, 60, false, '[]'::jsonb
  ) RETURNING id INTO v_locked_bonus_id;

  -- Use the effective awarded_by (never null)
  INSERT INTO user_bonuses (
    user_id, bonus_type_id, bonus_type_name, amount, status,
    awarded_by, awarded_at, expires_at, notes, is_locked, locked_bonus_id
  ) VALUES (
    p_user_id, p_bonus_type_id, v_bonus_type_name || ' (Locked)', p_amount, 'active',
    v_effective_awarded_by, now(), v_expires_at, p_notes, true, v_locked_bonus_id
  ) RETURNING id INTO v_user_bonus_id;

  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details
  ) VALUES (
    p_user_id, 'bonus', 'USDT', p_amount, 'completed',
    'Locked Bonus: ' || v_bonus_type_name || ' - Complete $' || ROUND(v_volume_required, 2)::text || ' trading volume to unlock (Expires: ' || to_char(v_expires_at, 'YYYY-MM-DD') || ')'
  );

  INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
  VALUES (
    p_user_id,
    'account_update',
    'Locked Bonus Awarded!',
    'You received $' || ROUND(p_amount, 2)::text || ' USDT locked bonus! ' ||
    'Use it for futures trading - profits are yours to keep! ' ||
    'To unlock and withdraw: Complete $' || ROUND(v_volume_required, 2)::text || ' in trading volume using the bonus funds. ' ||
    'Important: Positions must be held for at least 60 minutes to count. ' ||
    'Expires in ' || p_expiry_days || ' days.',
    false,
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name,
      'expires_at', v_expires_at,
      'volume_required', v_volume_required,
      'minimum_duration_minutes', 60
    ),
    '/wallet'
  );

  -- Only log to admin activity if awarded by an admin (not self-claimed)
  IF p_awarded_by IS NOT NULL AND p_awarded_by != p_user_id THEN
    INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
    VALUES (
      p_awarded_by, 
      'award_locked_bonus', 
      'Awarded locked bonus: ' || v_bonus_type_name || ' ($' || p_amount || ')',
      p_user_id,
      jsonb_build_object(
        'locked_bonus_id', v_locked_bonus_id,
        'amount', p_amount,
        'bonus_type', v_bonus_type_name,
        'expiry_days', p_expiry_days,
        'expires_at', v_expires_at,
        'volume_required', v_volume_required,
        'minimum_duration_minutes', 60
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'locked_bonus_id', v_locked_bonus_id,
    'amount', p_amount,
    'expires_at', v_expires_at,
    'volume_required', v_volume_required,
    'minimum_duration_minutes', 60,
    'message', 'Locked bonus awarded successfully with volume requirement of $' || ROUND(v_volume_required, 2)::text
  );
END;
$$;

GRANT EXECUTE ON FUNCTION award_locked_bonus TO authenticated;
