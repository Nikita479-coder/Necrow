/*
  # Create Admin Grant Copy Trading Credit Function

  1. New Function: `grant_copy_trading_credit`
    - Admin grants non-withdrawable credit to user's copy wallet
    - Credit can only be used for copy trading
    - Creates transaction, notification, and audit log
    - Multiple credits stack (each tracked separately)

  2. New Function: `get_user_copy_trading_credits`
    - Returns user's available and locked credits with details
*/

CREATE OR REPLACE FUNCTION grant_copy_trading_credit(
  p_user_id uuid,
  p_amount numeric,
  p_notes text DEFAULT NULL,
  p_awarded_by uuid DEFAULT NULL,
  p_expiry_days integer DEFAULT 90,
  p_lock_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credit_id uuid;
  v_awarded_by uuid;
  v_expires_at timestamptz;
  v_username text;
BEGIN
  v_awarded_by := COALESCE(p_awarded_by, auth.uid());

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  IF p_amount > 10000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maximum credit amount is 10,000 USDT');
  END IF;

  SELECT username INTO v_username
  FROM user_profiles WHERE id = p_user_id;

  IF v_username IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_expires_at := CASE
    WHEN p_expiry_days > 0 THEN now() + (p_expiry_days || ' days')::interval
    ELSE NULL
  END;

  INSERT INTO copy_trading_credits (
    user_id, amount, remaining_amount, status, granted_by,
    notes, lock_days, expires_at
  ) VALUES (
    p_user_id, p_amount, p_amount, 'available', v_awarded_by,
    p_notes, p_lock_days, v_expires_at
  ) RETURNING id INTO v_credit_id;

  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (p_user_id, 'USDT', 'copy', p_amount, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + p_amount,
    updated_at = now();

  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details, confirmed_at
  ) VALUES (
    p_user_id, 'reward', 'USDT', p_amount, 'completed',
    jsonb_build_object(
      'type', 'copy_trading_credit',
      'credit_id', v_credit_id,
      'non_withdrawable', true,
      'lock_days', p_lock_days,
      'note', COALESCE(p_notes, 'Copy trading credit')
    ),
    now()
  );

  INSERT INTO notifications (
    user_id, type, title, message, read, data, redirect_url, created_at
  ) VALUES (
    p_user_id,
    'reward',
    'Copy Trading Credit Received!',
    'You received $' || ROUND(p_amount, 2)::text || ' USDT copy trading credit! ' ||
    'This credit can only be used for copy trading and is non-withdrawable. ' ||
    'Start copy trading and keep it active for ' || p_lock_days || ' days to unlock profits. ' ||
    CASE WHEN v_expires_at IS NOT NULL THEN
      'Credit expires on ' || to_char(v_expires_at, 'Mon DD, YYYY') || ' if unused.'
    ELSE '' END,
    false,
    jsonb_build_object(
      'credit_id', v_credit_id,
      'amount', p_amount,
      'lock_days', p_lock_days,
      'expires_at', v_expires_at
    ),
    '/copytrading',
    now()
  );

  IF v_awarded_by IS NOT NULL AND v_awarded_by != p_user_id THEN
    INSERT INTO admin_activity_logs (
      admin_id, action_type, action_description, target_user_id, metadata
    ) VALUES (
      v_awarded_by,
      'grant_copy_trading_credit',
      'Granted $' || ROUND(p_amount, 2)::text || ' copy trading credit to ' || v_username,
      p_user_id,
      jsonb_build_object(
        'credit_id', v_credit_id,
        'amount', p_amount,
        'lock_days', p_lock_days,
        'expires_at', v_expires_at,
        'notes', p_notes
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'credit_id', v_credit_id,
    'amount', p_amount,
    'lock_days', p_lock_days,
    'expires_at', v_expires_at,
    'message', 'Copy trading credit of $' || ROUND(p_amount, 2)::text || ' granted successfully'
  );
END;
$$;


CREATE OR REPLACE FUNCTION get_user_copy_trading_credits(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_available_total numeric := 0;
  v_locked_total numeric := 0;
  v_credits jsonb;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT
    COALESCE(SUM(CASE WHEN status = 'available' THEN remaining_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN status = 'locked_in_relationship' THEN remaining_amount ELSE 0 END), 0)
  INTO v_available_total, v_locked_total
  FROM copy_trading_credits
  WHERE user_id = v_user_id
    AND status IN ('available', 'locked_in_relationship');

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'amount', amount,
      'remaining_amount', remaining_amount,
      'status', status,
      'relationship_id', relationship_id,
      'lock_days', lock_days,
      'locked_until', locked_until,
      'expires_at', expires_at,
      'days_until_unlock', CASE
        WHEN locked_until IS NOT NULL AND locked_until > now() THEN
          GREATEST(0, EXTRACT(DAY FROM locked_until - now())::integer)
        ELSE 0
      END,
      'created_at', created_at
    ) ORDER BY created_at DESC
  ), '[]'::jsonb)
  INTO v_credits
  FROM copy_trading_credits
  WHERE user_id = v_user_id
    AND status IN ('available', 'locked_in_relationship');

  RETURN jsonb_build_object(
    'success', true,
    'available_credit', v_available_total,
    'locked_credit', v_locked_total,
    'total_credit', v_available_total + v_locked_total,
    'credits', v_credits
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_copy_trading_credits TO authenticated;
