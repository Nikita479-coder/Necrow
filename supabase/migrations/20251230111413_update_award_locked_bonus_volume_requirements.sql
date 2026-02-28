/*
  # Update award_locked_bonus with Volume Requirements

  ## Summary
  Updates the award_locked_bonus function to set trading volume requirements
  instead of deposit and trade count requirements. Sets requirement to 500x
  the bonus amount and clearly communicates this to users.

  ## Changes
  1. Set bonus_trading_volume_required to amount * 500
  2. Set minimum_position_duration_minutes to 60
  3. Update notification message with clear requirements
  4. Remove any references to deposit/trade count requirements

  ## Example
  - $100 bonus = $50,000 trading volume required
  - Positions using bonus must be held 60+ minutes to count
  - Real wallet positions have no time restriction

  ## Security
  - Existing SECURITY DEFINER maintained
  - Volume tracking automatically handled by close_position
*/

CREATE OR REPLACE FUNCTION award_locked_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid,
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
BEGIN
  -- Validate bonus type exists and is active
  SELECT name INTO v_bonus_type_name
  FROM bonus_types
  WHERE id = p_bonus_type_id AND is_active = true;

  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;

  -- Validate expiry days
  IF p_expiry_days IS NULL OR p_expiry_days < 1 THEN
    p_expiry_days := 7;
  END IF;

  -- Calculate expiry date
  v_expires_at := now() + (p_expiry_days || ' days')::interval;

  -- Calculate volume requirement (500x the bonus amount)
  v_volume_required := p_amount * 500;

  -- Get username for notification
  SELECT username INTO v_username
  FROM user_profiles
  WHERE id = p_user_id;

  -- Create locked bonus record with volume requirements
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
    bonus_trading_volume_required,
    bonus_trading_volume_completed,
    minimum_position_duration_minutes,
    withdrawal_review_required,
    abuse_flags
  ) VALUES (
    p_user_id,
    p_amount,
    p_amount,
    0,
    p_bonus_type_id,
    v_bonus_type_name,
    p_awarded_by,
    p_notes,
    'active',
    v_expires_at,
    v_volume_required,
    0,
    60,
    false,
    '[]'::jsonb
  ) RETURNING id INTO v_locked_bonus_id;

  -- Create user_bonuses record for tracking
  INSERT INTO user_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    amount,
    status,
    awarded_by,
    awarded_at,
    expires_at,
    notes,
    is_locked,
    locked_bonus_id
  ) VALUES (
    p_user_id,
    p_bonus_type_id,
    v_bonus_type_name || ' (Locked)',
    p_amount,
    'active',
    p_awarded_by,
    now(),
    v_expires_at,
    p_notes,
    true,
    v_locked_bonus_id
  ) RETURNING id INTO v_user_bonus_id;

  -- Log transaction (no actual wallet credit)
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    metadata
  ) VALUES (
    p_user_id,
    'bonus',
    'USDT',
    p_amount,
    'completed',
    'Locked Bonus: ' || v_bonus_type_name || ' - Complete $' || ROUND(v_volume_required, 2)::text || ' trading volume to unlock (Expires: ' || to_char(v_expires_at, 'YYYY-MM-DD') || ')',
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'bonus_type', v_bonus_type_name,
      'awarded_by', p_awarded_by,
      'is_locked', true,
      'expires_at', v_expires_at,
      'expiry_days', p_expiry_days,
      'volume_required', v_volume_required,
      'minimum_duration_minutes', 60
    )
  );

  -- Send notification to user with clear requirements
  INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
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
      'minimum_duration_minutes', 60,
      'redirect_url', '/wallet'
    )
  );

  -- Log admin action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    p_awarded_by,
    'award_locked_bonus',
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION award_locked_bonus(uuid, uuid, numeric, uuid, text, integer) TO authenticated;
