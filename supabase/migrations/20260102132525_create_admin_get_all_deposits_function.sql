/*
  # Create Optimized Admin Get All Deposits Function

  1. Purpose
    - Single efficient query to fetch all deposits with user info
    - Replaces N+1 query pattern in frontend
    - Joins user profiles and emails server-side

  2. Returns
    - All deposit fields plus user email and name
*/

CREATE OR REPLACE FUNCTION admin_get_all_deposits(
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 200,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean := false;
  v_deposits jsonb;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  SELECT up.is_admin INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = v_user_id;
  
  IF v_is_admin IS NOT TRUE THEN
    v_is_admin := COALESCE((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false);
  END IF;
  
  IF v_is_admin IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'payment_id', cd.payment_id,
      'user_id', cd.user_id,
      'user_email', au.email,
      'user_name', COALESCE(up.full_name, up.username, 'Unknown'),
      'nowpayments_payment_id', cd.nowpayments_payment_id,
      'price_amount', cd.price_amount,
      'price_currency', cd.price_currency,
      'pay_amount', cd.pay_amount,
      'pay_currency', cd.pay_currency,
      'pay_address', cd.pay_address,
      'status', cd.status,
      'actually_paid', cd.actually_paid,
      'outcome_amount', cd.outcome_amount,
      'created_at', cd.created_at,
      'updated_at', cd.updated_at,
      'completed_at', cd.completed_at,
      'expires_at', cd.expires_at,
      'wallet_type', cd.wallet_type
    ) ORDER BY cd.created_at DESC
  )
  INTO v_deposits
  FROM crypto_deposits cd
  JOIN auth.users au ON au.id = cd.user_id
  LEFT JOIN user_profiles up ON up.id = cd.user_id
  WHERE (p_status IS NULL OR cd.status = p_status)
  LIMIT p_limit
  OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'deposits', COALESCE(v_deposits, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_all_deposits TO authenticated;
