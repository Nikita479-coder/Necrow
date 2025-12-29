/*
  # Fix Referral Tracking Aggregation
  
  1. Changes
    - Fix aggregation to properly handle multiple joins
    - Use subqueries to pre-aggregate data before joining
    - Prevent duplicate counting in aggregations
  
  2. Security
    - Maintain admin-only access
*/

-- Drop and recreate get_referrer_statistics with proper aggregation
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
      referrer_id,
      SUM(commission_amount) as total_commissions
    FROM referral_commissions
    GROUP BY referrer_id
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
    COALESCE(cs.total_commissions, 0) as total_commissions_earned,
    CASE 
      WHEN COUNT(rs.referee_id) > 0 
      THEN (COALESCE(SUM(rs.trading_volume), 0) + COALESCE(SUM(rs.deposit_sum), 0)) / COUNT(rs.referee_id)
      ELSE 0 
    END as avg_user_value
  FROM user_profiles referrer
  JOIN referred_stats rs ON rs.referred_by = referrer.id
  LEFT JOIN auth.users referrer_auth ON referrer_auth.id = referrer.id
  LEFT JOIN commission_sums cs ON cs.referrer_id = referrer.id
  GROUP BY referrer.id, referrer.full_name, referrer_auth.email, referrer.referral_code, cs.total_commissions
  ORDER BY COUNT(rs.referee_id) DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
