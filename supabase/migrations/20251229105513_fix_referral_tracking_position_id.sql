/*
  # Fix Referral Tracking Position ID
  
  1. Changes
    - Fix get_referrer_statistics to use position_id instead of id for futures_positions
    - Fix get_referred_users_details to use position_id instead of id for futures_positions
  
  2. Security
    - Maintain admin-only access
*/

-- Drop and recreate get_referrer_statistics with correct position_id
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
  is_admin_user boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO is_admin_user
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF is_admin_user IS NOT TRUE THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  RETURN QUERY
  WITH referrer_users AS (
    SELECT 
      up.referred_by,
      up.id as user_id,
      up.created_at,
      CASE WHEN COUNT(fp.position_id) > 0 THEN true ELSE false END as is_trader,
      CASE WHEN SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END) > 0 THEN true ELSE false END as has_deposited,
      COALESCE(SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END), 0) as total_deposits,
      COALESCE(rs.total_volume_all_time, 0) as trading_volume
    FROM user_profiles up
    LEFT JOIN futures_positions fp ON fp.user_id = up.id
    LEFT JOIN transactions t ON t.user_id = up.id
    LEFT JOIN referral_stats rs ON rs.user_id = up.id
    WHERE up.referred_by IS NOT NULL
    GROUP BY up.referred_by, up.id, up.created_at, rs.total_volume_all_time
  ),
  referrer_stats AS (
    SELECT
      ru.referred_by as referrer_id,
      COUNT(DISTINCT ru.user_id) as total_referrals,
      COUNT(DISTINCT CASE WHEN ru.is_trader THEN ru.user_id END) as active_traders,
      COUNT(DISTINCT CASE WHEN ru.has_deposited THEN ru.user_id END) as depositors,
      COALESCE(SUM(ru.total_deposits), 0) as total_deposit_amount,
      COALESCE(SUM(ru.trading_volume), 0) as total_trading_volume
    FROM referrer_users ru
    GROUP BY ru.referred_by
  ),
  commission_totals AS (
    SELECT
      rc.referrer_id,
      COALESCE(SUM(rc.commission_amount), 0) as total_commissions
    FROM referral_commissions rc
    GROUP BY rc.referrer_id
  )
  SELECT
    rs.referrer_id,
    up.full_name as referrer_name,
    au.email as referrer_email,
    up.referral_code as referrer_code,
    rs.total_referrals,
    rs.active_traders,
    rs.depositors,
    rs.total_deposit_amount,
    rs.total_trading_volume,
    COALESCE(ct.total_commissions, 0) as total_commissions_earned,
    CASE 
      WHEN rs.total_referrals > 0 
      THEN (rs.total_trading_volume + rs.total_deposit_amount) / rs.total_referrals
      ELSE 0 
    END as avg_user_value
  FROM referrer_stats rs
  JOIN user_profiles up ON up.id = rs.referrer_id
  LEFT JOIN auth.users au ON au.id = rs.referrer_id
  LEFT JOIN commission_totals ct ON ct.referrer_id = rs.referrer_id
  WHERE rs.total_referrals > 0
  ORDER BY rs.total_referrals DESC;
END;
$$;

-- Drop and recreate get_referred_users_details with correct position_id
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
  is_admin_user boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO is_admin_user
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF is_admin_user IS NOT TRUE THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  RETURN QUERY
  SELECT
    up.id,
    up.full_name,
    COALESCE(au.email, '') as email,
    up.country,
    up.created_at,
    CASE WHEN COUNT(DISTINCT fp.position_id) > 0 THEN true ELSE false END as is_trader,
    CASE WHEN SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END) > 0 THEN true ELSE false END as has_deposited,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END), 0) as total_deposits,
    COALESCE(rs.total_volume_all_time, 0) as trading_volume,
    COALESCE(up.kyc_status, 'pending') as kyc_status
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN futures_positions fp ON fp.user_id = up.id
  LEFT JOIN transactions t ON t.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_referrer_id
  GROUP BY up.id, up.full_name, au.email, up.country, up.created_at, up.kyc_status, rs.total_volume_all_time
  ORDER BY up.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_referred_users_details(uuid) TO authenticated;
