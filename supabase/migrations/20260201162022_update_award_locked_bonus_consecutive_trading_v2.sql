/*
  # Update award_locked_bonus for Consecutive Trading Requirements v2

  ## Summary
  Updates the award_locked_bonus function to support the new combined KYC + TrustPilot
  bonus that requires consecutive trading days.

  ## Changes
  - Drops all existing versions of the function
  - Creates new version with consecutive trading support
  - For KYC + TrustPilot Review Bonus: sets 30 consecutive days, 2 trades/day, 15 min minimum
*/

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS award_locked_bonus(uuid, uuid, numeric, uuid, text, integer);
DROP FUNCTION IF EXISTS award_locked_bonus(uuid, uuid, numeric, uuid, text, integer, integer, integer, integer);

-- Create updated function with consecutive trading support
CREATE FUNCTION award_locked_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_expiry_days integer DEFAULT 7,
  p_consecutive_days integer DEFAULT NULL,
  p_daily_trades integer DEFAULT NULL,
  p_daily_duration_minutes integer DEFAULT NULL
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
  v_is_combined_bonus boolean := false;
  v_notification_message text;
BEGIN
  -- If awarded_by is NULL, the user is claiming it themselves
  v_effective_awarded_by := COALESCE(p_awarded_by, p_user_id);

  -- Validate bonus type
  SELECT name INTO v_bonus_type_name
  FROM bonus_types
  WHERE id = p_bonus_type_id AND is_active = true;

  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  -- Check if this is the combined KYC + TrustPilot bonus
  IF v_bonus_type_name = 'KYC + TrustPilot Review Bonus' THEN
    v_is_combined_bonus := true;
    -- Set defaults for combined bonus if not specified
    p_expiry_days := COALESCE(p_expiry_days, 30);
    p_consecutive_days := COALESCE(p_consecutive_days, 30);
    p_daily_trades := COALESCE(p_daily_trades, 2);
    p_daily_duration_minutes := COALESCE(p_daily_duration_minutes, 15);
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;

  -- Validate and set expiry days
  IF p_expiry_days IS NULL OR p_expiry_days < 1 THEN
    p_expiry_days := 7;
  END IF;

  v_expires_at := now() + (p_expiry_days || ' days')::interval;
  v_volume_required := p_amount * 500;

  SELECT username INTO v_username
  FROM user_profiles
  WHERE id = p_user_id;

  -- Create locked bonus with all parameters
  INSERT INTO locked_bonuses (
    user_id, original_amount, current_amount, realized_profits,
    bonus_type_id, bonus_type_name, awarded_by, notes, status, expires_at,
    bonus_trading_volume_required, bonus_trading_volume_completed,
    minimum_position_duration_minutes, withdrawal_review_required, abuse_flags,
    consecutive_trading_days_required, current_consecutive_days,
    daily_trades_required, daily_trade_duration_minutes,
    daily_trade_count_today, last_qualifying_trade_date
  ) VALUES (
    p_user_id, p_amount, p_amount, 0,
    p_bonus_type_id, v_bonus_type_name, v_effective_awarded_by, p_notes, 'active', v_expires_at,
    v_volume_required, 0, 10, false, '[]'::jsonb,
    p_consecutive_days, 0,
    p_daily_trades, p_daily_duration_minutes,
    0, NULL
  ) RETURNING id INTO v_locked_bonus_id;

  -- Create user bonus record
  INSERT INTO user_bonuses (
    user_id, bonus_type_id, bonus_type_name, amount, status,
    awarded_by, awarded_at, expires_at, notes, is_locked, locked_bonus_id
  ) VALUES (
    p_user_id, p_bonus_type_id, v_bonus_type_name || ' (Locked)', p_amount, 'active',
    v_effective_awarded_by, now(), v_expires_at, p_notes, true, v_locked_bonus_id
  ) RETURNING id INTO v_user_bonus_id;

  -- Build appropriate notification message
  IF v_is_combined_bonus THEN
    v_notification_message := 'You received $' || ROUND(p_amount, 2)::text || ' USDT locked bonus! ' ||
      'To unlock: 1) Complete $' || ROUND(v_volume_required, 2)::text || ' in trading volume, AND ' ||
      '2) Trade for ' || p_consecutive_days || ' consecutive days (min ' || p_daily_trades || ' trades/day, ' || p_daily_duration_minutes || '+ min each). ' ||
      'Missing a day resets your streak! Expires in ' || p_expiry_days || ' days.';
  ELSE
    v_notification_message := 'You received $' || ROUND(p_amount, 2)::text || ' USDT locked bonus! ' ||
      'Use it for futures trading - profits are yours to keep! ' ||
      'To unlock and withdraw: Complete $' || ROUND(v_volume_required, 2)::text || ' in trading volume using the bonus funds. ' ||
      'Important: Positions must be held for at least 10 minutes to count. ' ||
      'Expires in ' || p_expiry_days || ' days.';
  END IF;

  -- Create transaction record
  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details
  ) VALUES (
    p_user_id, 'bonus', 'USDT', p_amount, 'completed',
    CASE WHEN v_is_combined_bonus THEN
      'Locked Bonus: ' || v_bonus_type_name || ' - Complete $' || ROUND(v_volume_required, 2)::text || ' volume + ' || p_consecutive_days || ' consecutive trading days'
    ELSE
      'Locked Bonus: ' || v_bonus_type_name || ' - Complete $' || ROUND(v_volume_required, 2)::text || ' trading volume to unlock (Expires: ' || to_char(v_expires_at, 'YYYY-MM-DD') || ')'
    END
  );

  -- Create notification
  INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
  VALUES (
    p_user_id,
    'account_update',
    'Locked Bonus Awarded!',
    v_notification_message,
    false,
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name,
      'expires_at', v_expires_at,
      'volume_required', v_volume_required,
      'minimum_duration_minutes', 10,
      'consecutive_days_required', p_consecutive_days,
      'daily_trades_required', p_daily_trades,
      'daily_trade_duration_minutes', p_daily_duration_minutes
    ),
    '/wallet'
  );

  -- Log admin action if awarded by admin (not self-claimed)
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
        'minimum_duration_minutes', 10,
        'consecutive_days_required', p_consecutive_days,
        'daily_trades_required', p_daily_trades,
        'daily_trade_duration_minutes', p_daily_duration_minutes
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'locked_bonus_id', v_locked_bonus_id,
    'amount', p_amount,
    'expires_at', v_expires_at,
    'volume_required', v_volume_required,
    'minimum_duration_minutes', 10,
    'consecutive_days_required', p_consecutive_days,
    'daily_trades_required', p_daily_trades,
    'daily_trade_duration_minutes', p_daily_duration_minutes,
    'message', CASE WHEN v_is_combined_bonus THEN
      'Locked bonus awarded with volume requirement of $' || ROUND(v_volume_required, 2)::text || ' and ' || p_consecutive_days || ' consecutive trading days'
    ELSE
      'Locked bonus awarded successfully with volume requirement of $' || ROUND(v_volume_required, 2)::text
    END
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION award_locked_bonus TO authenticated;
