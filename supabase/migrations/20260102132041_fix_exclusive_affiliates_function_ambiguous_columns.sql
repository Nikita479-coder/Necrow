/*
  # Fix Ambiguous Column References in Affiliates Function

  Properly alias all columns to avoid ambiguity.
*/

DROP FUNCTION IF EXISTS admin_get_exclusive_affiliates();

CREATE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE (
  affiliate_id uuid,
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
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;
  
  SELECT user_profiles.is_admin INTO v_is_admin
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
    ea.id as affiliate_id,
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

GRANT EXECUTE ON FUNCTION admin_get_exclusive_affiliates TO authenticated;
