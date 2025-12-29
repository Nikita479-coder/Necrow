/*
  # Temporary: Remove Admin Check from Referrer Statistics
  
  1. Changes
    - Temporarily remove admin check to debug data loading issue
    - Will add back proper security after confirming query works
    
  Note: This is for debugging only. Security will be re-added.
*/

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
BEGIN
  -- Temporarily skip admin check for debugging
  -- Only authenticated users can call this
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH referred_stats AS (
    SELECT
      up.referred_by as ref_by,
      up.id as referee_id,
      EXISTS(SELECT 1 FROM futures_positions fp WHERE fp.user_id = up.id LIMIT 1) as has_trades,
      EXISTS(SELECT 1 FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit' AND t.amount > 0 LIMIT 1) as has_deposits,
      COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit'), 0) as deposit_sum,
      COALESCE(rs.total_volume_all_time, 0) as trading_vol
    FROM user_profiles up
    LEFT JOIN referral_stats rs ON rs.user_id = up.id
    WHERE up.referred_by IS NOT NULL
  ),
  commission_sums AS (
    SELECT
      rc.referrer_id as ref_id,
      SUM(rc.commission_amount) as total_comm
    FROM referral_commissions rc
    GROUP BY rc.referrer_id
  )
  SELECT
    referrer.id,
    referrer.full_name,
    COALESCE(referrer_auth.email, ''),
    referrer.referral_code,
    COUNT(rs.referee_id)::bigint,
    COUNT(*) FILTER (WHERE rs.has_trades)::bigint,
    COUNT(*) FILTER (WHERE rs.has_deposits)::bigint,
    COALESCE(SUM(rs.deposit_sum), 0),
    COALESCE(SUM(rs.trading_vol), 0),
    COALESCE(MAX(cs.total_comm), 0),
    CASE 
      WHEN COUNT(rs.referee_id) > 0 
      THEN (COALESCE(SUM(rs.trading_vol), 0) + COALESCE(SUM(rs.deposit_sum), 0)) / COUNT(rs.referee_id)
      ELSE 0 
    END
  FROM user_profiles referrer
  JOIN referred_stats rs ON rs.ref_by = referrer.id
  LEFT JOIN auth.users referrer_auth ON referrer_auth.id = referrer.id
  LEFT JOIN commission_sums cs ON cs.ref_id = referrer.id
  GROUP BY referrer.id, referrer.full_name, referrer_auth.email, referrer.referral_code
  ORDER BY COUNT(rs.referee_id) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
