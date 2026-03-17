/*
  # Fix Copy Trading Credit Grant - Use auth.users Instead

  1. Changes
    - Query auth.users instead of user_profiles to avoid RLS
    - auth.users is not subject to RLS policies
    - Still maintains all security checks
  
  2. Security
    - Admin check remains in place
    - Function is SECURITY DEFINER so can access auth schema
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
  v_is_admin boolean;
  v_user_exists boolean;
BEGIN
  v_awarded_by := COALESCE(p_awarded_by, auth.uid());

  -- Check if caller is admin
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
    false
  ) INTO v_is_admin;

  IF NOT v_is_admin THEN
    SELECT EXISTS(
      SELECT 1 FROM public.user_profiles WHERE id = v_awarded_by AND is_admin = true
    ) INTO v_is_admin;
  END IF;

  IF NOT v_is_admin THEN
    SELECT EXISTS(
      SELECT 1 FROM public.admin_staff WHERE id = v_awarded_by AND is_active = true
    ) INTO v_is_admin;
  END IF;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Access denied: admin privileges required');
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  IF p_amount > 10000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maximum credit amount is 10,000 USDT');
  END IF;

  -- Check if user exists using auth.users (not subject to RLS)
  SELECT EXISTS(
    SELECT 1 FROM auth.users WHERE id = p_user_id
  ) INTO v_user_exists;

  IF NOT v_user_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Get username for logging (optional, doesn't fail if not found)
  SELECT username INTO v_username
  FROM user_profiles WHERE id = p_user_id;

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
      'Granted $' || ROUND(p_amount, 2)::text || ' copy trading credit to ' || COALESCE(v_username, 'User ' || p_user_id::text),
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
