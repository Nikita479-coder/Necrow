/*
  # Fix Referrer Statistics - Remove auth.users Join
  
  1. Problem
    - The function cannot access auth.users table via RPC even with SECURITY DEFINER
    - This causes the query to return empty results
    
  2. Solution
    - Remove the join to auth.users
    - Store email in user_profiles or fetch separately
    - Return empty string for email for now (admin can see it elsewhere)
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
DECLARE
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;
  
  SELECT COALESCE(up.is_admin, false) INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = v_user_id;
  
  IF NOT v_is_admin THEN
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
    ''::text as email,
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
  LEFT JOIN commission_sums cs ON cs.ref_id = referrer.id
  GROUP BY referrer.id, referrer.full_name, referrer.referral_code
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
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;
  
  SELECT COALESCE(up.is_admin, false) INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = v_user_id;
  
  IF NOT v_is_admin THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    up.id,
    up.full_name,
    ''::text as email,
    up.country,
    up.created_at,
    EXISTS(SELECT 1 FROM futures_positions fp WHERE fp.user_id = up.id LIMIT 1),
    EXISTS(SELECT 1 FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit' AND t.amount > 0 LIMIT 1),
    COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.user_id = up.id AND t.transaction_type = 'deposit'), 0),
    COALESCE(rs.total_volume_all_time, 0),
    COALESCE(up.kyc_status, 'pending')
  FROM user_profiles up
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_referrer_id
  ORDER BY up.created_at DESC;
END;
$$;

-- Clean up test function
DROP FUNCTION IF EXISTS test_referrer_count();

GRANT EXECUTE ON FUNCTION get_referrer_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION get_referred_users_details(uuid) TO authenticated;
