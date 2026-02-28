/*
  # Fix Ambiguous Column Reference in Withdrawals Function

  The "id" column was ambiguous - need to prefix with table alias.
*/

DROP FUNCTION IF EXISTS admin_get_exclusive_withdrawals();

CREATE FUNCTION admin_get_exclusive_withdrawals()
RETURNS TABLE (
  withdrawal_id uuid,
  user_id uuid,
  email text,
  full_name text,
  amount numeric,
  currency text,
  wallet_address text,
  network text,
  status text,
  created_at timestamptz,
  processed_by_email text,
  processed_at timestamptz,
  rejection_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;
  
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_profiles.id = v_user_id;
  
  IF v_is_admin IS NOT TRUE THEN
    v_is_admin := COALESCE((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false);
  END IF;
  
  IF v_is_admin IS NOT TRUE THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT
    eaw.id as withdrawal_id,
    eaw.user_id,
    au.email::text,
    up.full_name,
    eaw.amount,
    eaw.currency,
    eaw.wallet_address,
    eaw.network,
    eaw.status,
    eaw.created_at,
    processed_by_user.email::text as processed_by_email,
    eaw.processed_at,
    eaw.rejection_reason
  FROM exclusive_affiliate_withdrawals eaw
  JOIN auth.users au ON au.id = eaw.user_id
  JOIN user_profiles up ON up.id = eaw.user_id
  LEFT JOIN auth.users processed_by_user ON processed_by_user.id = eaw.processed_by
  ORDER BY 
    CASE WHEN eaw.status = 'pending' THEN 0 ELSE 1 END,
    eaw.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_exclusive_withdrawals TO authenticated;
