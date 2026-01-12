/*
  # Fix admin_get_exclusive_affiliates Type Mismatch

  ## Issue
  The function returns an integer when adding level_count columns, but the
  RETURNS TABLE expects bigint for network_size column.

  ## Solution
  Explicitly cast the sum to bigint to match the expected return type.
*/

DROP FUNCTION IF EXISTS admin_get_exclusive_affiliates();

CREATE OR REPLACE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE (
  affiliate_id uuid,
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  deposit_commission_rates jsonb,
  fee_share_rates jsonb,
  copy_profit_rates jsonb,
  is_active boolean,
  enrolled_at timestamptz,
  enrolled_by_email text,
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  deposit_commissions_earned numeric,
  fee_share_earned numeric,
  copy_profit_earned numeric,
  network_size bigint,
  this_month_earnings numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT
    ea.id as affiliate_id,
    ea.user_id,
    get_user_email(ea.user_id) as email,
    up.full_name,
    up.username,
    up.referral_code,
    ea.deposit_commission_rates,
    ea.fee_share_rates,
    COALESCE(ea.copy_profit_rates, '{}'::jsonb) as copy_profit_rates,
    ea.is_active,
    ea.created_at as enrolled_at,
    get_user_email(ea.enrolled_by) as enrolled_by_email,
    COALESCE(eab.available_balance, 0) as available_balance,
    COALESCE(eab.pending_balance, 0) as pending_balance,
    COALESCE(eab.total_earned, 0) as total_earned,
    COALESCE(eab.total_withdrawn, 0) as total_withdrawn,
    COALESCE(eab.deposit_commissions_earned, 0) as deposit_commissions_earned,
    COALESCE(eab.fee_share_earned, 0) as fee_share_earned,
    COALESCE(eab.copy_profit_earned, 0) as copy_profit_earned,
    (
      COALESCE(eans.level_1_count, 0)::bigint + COALESCE(eans.level_2_count, 0)::bigint + 
      COALESCE(eans.level_3_count, 0)::bigint + COALESCE(eans.level_4_count, 0)::bigint + 
      COALESCE(eans.level_5_count, 0)::bigint + COALESCE(eans.level_6_count, 0)::bigint +
      COALESCE(eans.level_7_count, 0)::bigint + COALESCE(eans.level_8_count, 0)::bigint + 
      COALESCE(eans.level_9_count, 0)::bigint + COALESCE(eans.level_10_count, 0)::bigint
    ) as network_size,
    COALESCE(eans.this_month_earnings, 0) as this_month_earnings
  FROM exclusive_affiliates ea
  JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN exclusive_affiliate_balances eab ON eab.user_id = ea.user_id
  LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
  ORDER BY ea.created_at DESC;
END;
$$;
