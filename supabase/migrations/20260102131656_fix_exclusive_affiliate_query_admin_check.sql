/*
  # Fix Exclusive Affiliate Query Admin Check

  ## Summary
  Updates the admin check to work correctly with RPC calls from the frontend.
  The issue was that the function returns empty if the check fails, but the 
  check itself may not work correctly in all contexts.

  ## Changes
  - Simplified admin check logic
*/

DROP FUNCTION IF EXISTS admin_get_exclusive_affiliates();

CREATE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  deposit_commission_rates jsonb,
  fee_share_rates jsonb,
  is_active boolean,
  enrolled_at timestamptz,
  enrolled_by_email text,
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  deposit_commissions_earned numeric,
  fee_share_earned numeric,
  network_size bigint,
  this_month_earnings numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF v_is_admin IS NOT TRUE THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT
    ea.id,
    ea.user_id,
    au.email::text,
    up.full_name,
    up.username,
    up.referral_code,
    ea.deposit_commission_rates,
    ea.fee_share_rates,
    ea.is_active,
    ea.created_at as enrolled_at,
    enrolled_by_user.email::text as enrolled_by_email,
    COALESCE(eab.available_balance, 0)::numeric as available_balance,
    COALESCE(eab.pending_balance, 0)::numeric as pending_balance,
    COALESCE(eab.total_earned, 0)::numeric as total_earned,
    COALESCE(eab.total_withdrawn, 0)::numeric as total_withdrawn,
    COALESCE(eab.deposit_commissions_earned, 0)::numeric as deposit_commissions_earned,
    COALESCE(eab.fee_share_earned, 0)::numeric as fee_share_earned,
    COALESCE(eans.level_1_count + eans.level_2_count + eans.level_3_count + eans.level_4_count + eans.level_5_count, 0)::bigint as network_size,
    COALESCE(eans.this_month_earnings, 0)::numeric as this_month_earnings
  FROM exclusive_affiliates ea
  JOIN auth.users au ON au.id = ea.user_id
  JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN auth.users enrolled_by_user ON enrolled_by_user.id = ea.enrolled_by
  LEFT JOIN exclusive_affiliate_balances eab ON eab.user_id = ea.user_id
  LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
  ORDER BY ea.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS admin_get_exclusive_withdrawals();

CREATE FUNCTION admin_get_exclusive_withdrawals()
RETURNS TABLE (
  id uuid,
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
  v_is_admin boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF v_is_admin IS NOT TRUE THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT
    eaw.id,
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

GRANT EXECUTE ON FUNCTION admin_get_exclusive_affiliates TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_exclusive_withdrawals TO authenticated;
