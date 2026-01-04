/*
  # Update Exclusive Affiliate Referrals Function
  
  Shows ALL referrals with eligibility flag:
  - eligible = true: Signed up AFTER enrollment (earns commissions)
  - eligible = false: Signed up BEFORE enrollment (no commissions)
*/

DROP FUNCTION IF EXISTS get_exclusive_affiliate_referrals(uuid);

CREATE OR REPLACE FUNCTION get_exclusive_affiliate_referrals(p_affiliate_id uuid)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  level int,
  registered_at timestamptz,
  total_deposits numeric,
  trading_volume numeric,
  eligible boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enrolled_at timestamptz;
BEGIN
  SELECT ea.created_at INTO v_enrolled_at
  FROM exclusive_affiliates ea
  WHERE ea.user_id = p_affiliate_id;
  
  IF v_enrolled_at IS NULL THEN
    v_enrolled_at := NOW();
  END IF;

  RETURN QUERY
  WITH RECURSIVE network AS (
    SELECT 
      up.id,
      1 as lvl,
      up.referred_by,
      up.created_at >= v_enrolled_at as is_eligible
    FROM user_profiles up
    WHERE up.referred_by = p_affiliate_id
    
    UNION ALL
    
    SELECT 
      up.id,
      n.lvl + 1,
      up.referred_by,
      up.created_at >= v_enrolled_at as is_eligible
    FROM user_profiles up
    JOIN network n ON up.referred_by = n.id
    WHERE n.lvl < 5
  )
  SELECT 
    n.id as user_id,
    au.email::text,
    up.full_name::text,
    up.username::text,
    n.lvl as level,
    up.created_at as registered_at,
    COALESCE(rs.total_volume_all_time, 0) as total_deposits,
    COALESCE(rs.total_volume_30d, 0) as trading_volume,
    n.is_eligible as eligible
  FROM network n
  JOIN user_profiles up ON up.id = n.id
  JOIN auth.users au ON au.id = n.id
  LEFT JOIN referral_stats rs ON rs.user_id = n.id
  ORDER BY n.is_eligible DESC, n.lvl, up.created_at DESC;
END;
$$;
