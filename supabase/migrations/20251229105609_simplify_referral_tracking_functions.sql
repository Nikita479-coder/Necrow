/*
  # Simplify Referral Tracking Functions
  
  1. Changes
    - Simplify get_referrer_statistics to avoid complex aggregations
    - Use simpler queries that directly aggregate from base tables
    - Ensure the function returns all referrers with at least one referral
  
  2. Security
    - Maintain admin-only access
*/

-- Drop and recreate get_referrer_statistics with simplified logic
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
  SELECT
    referrer.id as referrer_id,
    referrer.full_name as referrer_name,
    referrer_auth.email as referrer_email,
    referrer.referral_code as referrer_code,
    COUNT(DISTINCT referred.id)::bigint as total_referrals,
    COUNT(DISTINCT CASE WHEN fp.position_id IS NOT NULL THEN referred.id END)::bigint as active_traders,
    COUNT(DISTINCT CASE WHEN t.transaction_type = 'deposit' AND t.amount > 0 THEN referred.id END)::bigint as depositors,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END), 0) as total_deposit_amount,
    COALESCE(SUM(DISTINCT rs.total_volume_all_time), 0) as total_trading_volume,
    COALESCE(SUM(DISTINCT rc.commission_amount), 0) as total_commissions_earned,
    CASE 
      WHEN COUNT(DISTINCT referred.id) > 0 
      THEN (COALESCE(SUM(DISTINCT rs.total_volume_all_time), 0) + COALESCE(SUM(CASE WHEN t.transaction_type = 'deposit' THEN t.amount ELSE 0 END), 0)) / COUNT(DISTINCT referred.id)
      ELSE 0 
    END as avg_user_value
  FROM user_profiles referrer
  JOIN user_profiles referred ON referred.referred_by = referrer.id
  LEFT JOIN auth.users referrer_auth ON referrer_auth.id = referrer.id
  LEFT JOIN futures_positions fp ON fp.user_id = referred.id
  LEFT JOIN transactions t ON t.user_id = referred.id
  LEFT JOIN referral_stats rs ON rs.user_id = referred.id
  LEFT JOIN referral_commissions rc ON rc.referrer_id = referrer.id AND rc.referee_id = referred.id
  GROUP BY referrer.id, referrer.full_name, referrer_auth.email, referrer.referral_code
  HAVING COUNT(DISTINCT referred.id) > 0
  ORDER BY COUNT(DISTINCT referred.id) DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
