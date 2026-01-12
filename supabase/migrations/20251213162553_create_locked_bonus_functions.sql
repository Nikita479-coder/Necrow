/*
  # Create Locked Bonus Award and Management Functions

  ## Summary
  Creates functions to award, manage, and expire locked bonuses.

  ## Functions

  ### 1. award_locked_bonus
  Awards a locked bonus to a user - does NOT credit to wallet
  - Creates locked_bonuses record
  - Creates user_bonuses record with is_locked = true
  - Sends notification to user
  - Returns bonus details

  ### 2. apply_pnl_to_locked_bonus
  Called when closing futures positions to apply PnL
  - Losses are deducted from locked bonus first
  - Profits are credited to user's regular wallet

  ### 3. expire_locked_bonuses
  Expires all locked bonuses that have passed their expiration date

  ### 4. get_available_trading_balance
  Returns total balance available for futures trading (regular + locked)
*/

-- Function to award a locked bonus to a user
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

  -- Get username for notification
  SELECT username INTO v_username
  FROM user_profiles
  WHERE id = p_user_id;

  -- Create locked bonus record
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
    expires_at
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
    v_expires_at
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
    description,
    metadata
  ) VALUES (
    p_user_id,
    'bonus',
    'USDT',
    p_amount,
    'completed',
    'Locked Bonus: ' || v_bonus_type_name || ' (Expires: ' || to_char(v_expires_at, 'YYYY-MM-DD') || ')',
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'bonus_type', v_bonus_type_name,
      'awarded_by', p_awarded_by,
      'is_locked', true,
      'expires_at', v_expires_at,
      'expiry_days', p_expiry_days
    )
  );

  -- Send notification to user
  INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
  VALUES (
    p_user_id,
    'account_update',
    'Locked Bonus Awarded!',
    'You have received a locked bonus of $' || p_amount::text || ' USDT! This bonus can be used for futures trading but cannot be withdrawn. Profits from trading are yours to keep! Expires in ' || p_expiry_days || ' days.',
    false,
    jsonb_build_object(
      'locked_bonus_id', v_locked_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name,
      'expires_at', v_expires_at
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
      'expires_at', v_expires_at
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'locked_bonus_id', v_locked_bonus_id,
    'amount', p_amount,
    'expires_at', v_expires_at,
    'message', 'Locked bonus awarded successfully'
  );
END;
$$;

-- Function to apply PnL to locked bonus (called when closing futures positions)
CREATE OR REPLACE FUNCTION apply_pnl_to_locked_bonus(
  p_user_id uuid,
  p_pnl numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locked_bonus record;
  v_remaining_loss numeric;
  v_deduction numeric;
  v_total_deducted numeric := 0;
BEGIN
  -- If PnL is positive (profit), no action needed on locked bonus
  -- Profits go to regular wallet, handled elsewhere
  IF p_pnl >= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'action', 'profit_credited_to_wallet',
      'profit', p_pnl
    );
  END IF;

  -- For losses, deduct from locked bonuses (oldest first)
  v_remaining_loss := ABS(p_pnl);

  FOR v_locked_bonus IN 
    SELECT id, current_amount
    FROM locked_bonuses
    WHERE user_id = p_user_id 
      AND status = 'active'
      AND current_amount > 0
      AND expires_at > now()
    ORDER BY created_at ASC
  LOOP
    IF v_remaining_loss <= 0 THEN
      EXIT;
    END IF;

    -- Calculate how much to deduct from this bonus
    v_deduction := LEAST(v_locked_bonus.current_amount, v_remaining_loss);

    -- Update the locked bonus
    UPDATE locked_bonuses
    SET 
      current_amount = current_amount - v_deduction,
      updated_at = now(),
      status = CASE WHEN current_amount - v_deduction <= 0 THEN 'depleted' ELSE status END
    WHERE id = v_locked_bonus.id;

    v_total_deducted := v_total_deducted + v_deduction;
    v_remaining_loss := v_remaining_loss - v_deduction;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'loss_applied',
    'total_loss', ABS(p_pnl),
    'deducted_from_locked_bonus', v_total_deducted,
    'remaining_loss_from_wallet', v_remaining_loss
  );
END;
$$;

-- Function to expire old locked bonuses
CREATE OR REPLACE FUNCTION expire_locked_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_expired_bonus record;
BEGIN
  -- Find and expire all active locked bonuses past their expiration
  FOR v_expired_bonus IN
    SELECT id, user_id, original_amount, current_amount, bonus_type_name
    FROM locked_bonuses
    WHERE status = 'active'
      AND expires_at <= now()
  LOOP
    -- Update status to expired
    UPDATE locked_bonuses
    SET 
      status = 'expired',
      updated_at = now()
    WHERE id = v_expired_bonus.id;

    -- Update corresponding user_bonuses record
    UPDATE user_bonuses
    SET status = 'expired'
    WHERE locked_bonus_id = v_expired_bonus.id;

    -- Send notification to user
    INSERT INTO notifications (user_id, type, title, message, is_read, metadata)
    VALUES (
      v_expired_bonus.user_id,
      'account_update',
      'Locked Bonus Expired',
      'Your locked bonus of $' || v_expired_bonus.original_amount::text || ' (' || v_expired_bonus.bonus_type_name || ') has expired. Remaining balance of $' || v_expired_bonus.current_amount::text || ' has been removed.',
      false,
      jsonb_build_object(
        'locked_bonus_id', v_expired_bonus.id,
        'original_amount', v_expired_bonus.original_amount,
        'remaining_amount', v_expired_bonus.current_amount
      )
    );

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count
  );
END;
$$;

-- Function to get available trading balance (regular + locked)
CREATE OR REPLACE FUNCTION get_available_futures_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_futures_balance numeric := 0;
  v_locked_bonus_balance numeric := 0;
BEGIN
  -- Get futures margin wallet balance
  SELECT COALESCE(available_balance, 0) INTO v_futures_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  -- Get total active locked bonus balance
  SELECT COALESCE(SUM(current_amount), 0) INTO v_locked_bonus_balance
  FROM locked_bonuses
  WHERE user_id = p_user_id 
    AND status = 'active'
    AND expires_at > now();

  RETURN jsonb_build_object(
    'regular_balance', v_futures_balance,
    'locked_bonus_balance', v_locked_bonus_balance,
    'total_available', v_futures_balance + v_locked_bonus_balance
  );
END;
$$;

-- Function to check withdrawable balance (excludes locked bonus)
CREATE OR REPLACE FUNCTION get_withdrawable_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_futures_balance numeric := 0;
  v_locked_bonus_balance numeric := 0;
  v_total_withdrawable numeric := 0;
BEGIN
  -- Get main USDT wallet balance
  SELECT COALESCE(balance, 0) INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- Get futures margin wallet balance
  SELECT COALESCE(available_balance, 0) INTO v_futures_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  -- Get total active locked bonus balance (NOT withdrawable)
  SELECT COALESCE(SUM(current_amount), 0) INTO v_locked_bonus_balance
  FROM locked_bonuses
  WHERE user_id = p_user_id 
    AND status = 'active'
    AND expires_at > now();

  -- Total withdrawable is main + futures (excludes locked bonus)
  v_total_withdrawable := v_main_balance + v_futures_balance;

  RETURN jsonb_build_object(
    'main_balance', v_main_balance,
    'futures_balance', v_futures_balance,
    'locked_bonus_balance', v_locked_bonus_balance,
    'total_withdrawable', v_total_withdrawable,
    'locked_bonus_note', 'Locked bonus can be used for trading but cannot be withdrawn'
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION award_locked_bonus(uuid, uuid, numeric, uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_pnl_to_locked_bonus(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION expire_locked_bonuses() TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_futures_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_withdrawable_balance(uuid) TO authenticated;
