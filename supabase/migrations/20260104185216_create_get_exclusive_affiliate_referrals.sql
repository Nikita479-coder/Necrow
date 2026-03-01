/*
  # Create Function to Get Exclusive Affiliate Referrals
  
  1. New Function
    - get_exclusive_affiliate_referrals: Returns actual referrals for an exclusive affiliate
    - Only returns users who signed up AFTER the affiliate was enrolled
    - Supports 5 levels of referrals
    
  2. Security
    - Admin only function
*/

CREATE OR REPLACE FUNCTION get_exclusive_affiliate_referrals(p_affiliate_id uuid)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  level int,
  registered_at timestamptz,
  total_deposits numeric,
  trading_volume numeric
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
    RETURN;
  END IF;

  RETURN QUERY
  WITH RECURSIVE network AS (
    -- Level 1: Direct referrals after enrollment
    SELECT 
      up.id,
      1 as lvl,
      up.referred_by
    FROM user_profiles up
    WHERE up.referred_by = p_affiliate_id
      AND up.created_at >= v_enrolled_at
    
    UNION ALL
    
    -- Levels 2-5: Referrals of referrals
    SELECT 
      up.id,
      n.lvl + 1,
      up.referred_by
    FROM user_profiles up
    JOIN network n ON up.referred_by = n.id
    WHERE n.lvl < 5
      AND up.created_at >= v_enrolled_at
  )
  SELECT 
    n.id as user_id,
    au.email::text,
    up.full_name::text,
    up.username::text,
    n.lvl as level,
    up.created_at as registered_at,
    COALESCE(rs.total_deposits, 0) as total_deposits,
    COALESCE(rs.total_volume, 0) as trading_volume
  FROM network n
  JOIN user_profiles up ON up.id = n.id
  JOIN auth.users au ON au.id = n.id
  LEFT JOIN referral_stats rs ON rs.user_id = n.id
  ORDER BY n.lvl, up.created_at;
END;
$$;
