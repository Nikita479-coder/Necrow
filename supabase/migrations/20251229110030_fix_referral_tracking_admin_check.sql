/*
  # Fix Referral Tracking Admin Check
  
  1. Changes
    - Update get_referrer_statistics to check both JWT metadata AND user_profiles table
    - This handles cases where is_admin is set in profile but not in JWT
  
  2. Security
    - Maintain admin-only access through either method
*/

-- Drop and recreate get_referrer_statistics with fixed admin check
DROP FUNCTION IF EXISTS get_referrer_statistics();

CREATE OR REPLACE FUNCTION get_referrer_statistics()
RETURNS TABLE (
  referrer_id uuid,
  referrer_name text,
  referrer_email text,
  referrer_code text,
  total_referrals bigint,
  active_traders bigint,
  depositors bigint,
  total_deposit_amount numeric,
  total_trading_volume numeric,
  total_commissions_earned numeric,
  avg_user_value numeric
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  is_admin_jwt boolean;
  is_admin_profile boolean;
BEGIN
  -- Check JWT metadata first
  is_admin_jwt := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  -- Also check user_profiles table
  SELECT up.is_admin INTO is_admin_profile
  FROM user_profiles up
  WHERE up.id = auth.uid();
  
  -- Allow if either check passes
  IF is_admin_jwt IS NOT TRUE AND is_admin_profile IS NOT TRUE THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  RETURN QUERY
  WITH referred_stats AS (
    SELECT
      up.referred_by,
      up.id as referee_id,
      EXISTS(SELECT 1 FROM futures_positions WHERE user_id = up.id LIMIT 1) as has_trades,
      EXISTS(SELECT 1 FROM transactions WHERE user_id = up.id AND transaction_type = 'deposit' AND amount > 0 LIMIT 1) as has_deposits,
      COALESCE((SELECT SUM(amount) FROM transactions WHERE user_id = up.id AND transaction_type = 'deposit'), 0) as deposit_sum,
      COALESCE(rs.total_volume_all_time, 0) as trading_volume
    FROM user_profiles up
    LEFT JOIN referral_stats rs ON rs.user_id = up.id
    WHERE up.referred_by IS NOT NULL
  ),
  commission_sums AS (
    SELECT
      rc.referrer_id as ref_id,
      SUM(rc.commission_amount) as total_commissions
    FROM referral_commissions rc
    GROUP BY rc.referrer_id
  )
  SELECT
    referrer.id as referrer_id,
    referrer.full_name as referrer_name,
    referrer_auth.email as referrer_email,
    referrer.referral_code as referrer_code,
    COUNT(rs.referee_id)::bigint as total_referrals,
    COUNT(*) FILTER (WHERE rs.has_trades)::bigint as active_traders,
    COUNT(*) FILTER (WHERE rs.has_deposits)::bigint as depositors,
    COALESCE(SUM(rs.deposit_sum), 0) as total_deposit_amount,
    COALESCE(SUM(rs.trading_volume), 0) as total_trading_volume,
    COALESCE(MAX(cs.total_commissions), 0) as total_commissions_earned,
    CASE 
      WHEN COUNT(rs.referee_id) > 0 
      THEN (COALESCE(SUM(rs.trading_volume), 0) + COALESCE(SUM(rs.deposit_sum), 0)) / COUNT(rs.referee_id)
      ELSE 0 
    END as avg_user_value
  FROM user_profiles referrer
  JOIN referred_stats rs ON rs.referred_by = referrer.id
  LEFT JOIN auth.users referrer_auth ON referrer_auth.id = referrer.id
  LEFT JOIN commission_sums cs ON cs.ref_id = referrer.id
  GROUP BY referrer.id, referrer.full_name, referrer_auth.email, referrer.referral_code
  ORDER BY COUNT(rs.referee_id) DESC;
END;
$$;

-- Also fix get_referred_users_details
DROP FUNCTION IF EXISTS get_referred_users_details(uuid);

CREATE OR REPLACE FUNCTION get_referred_users_details(p_referrer_id uuid)
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  country text,
  created_at timestamptz,
  is_trader boolean,
  has_deposited boolean,
  total_deposits numeric,
  trading_volume numeric,
  kyc_status text
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  is_admin_jwt boolean;
  is_admin_profile boolean;
BEGIN
  -- Check JWT metadata first
  is_admin_jwt := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  -- Also check user_profiles table
  SELECT up.is_admin INTO is_admin_profile
  FROM user_profiles up
  WHERE up.id = auth.uid();
  
  -- Allow if either check passes
  IF is_admin_jwt IS NOT TRUE AND is_admin_profile IS NOT TRUE THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  RETURN QUERY
  SELECT
    up.id,
    up.full_name,
    COALESCE(au.email, '') as email,
    up.country,
    up.created_at,
    EXISTS(SELECT 1 FROM futures_positions fp WHERE fp.user_id = up.id LIMIT 1) as is_trader,
    EXISTS(SELECT 1 FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit' AND t.amount > 0 LIMIT 1) as has_deposited,
    COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit'), 0) as total_deposits,
    COALESCE(rs.total_volume_all_time, 0) as trading_volume,
    COALESCE(up.kyc_status, 'pending') as kyc_status
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_referrer_id
  ORDER BY up.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_referred_users_details(uuid) TO authenticated;
