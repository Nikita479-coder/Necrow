/*
  # Get Affiliate Network By Level Function

  1. New Functions
    - `get_affiliate_network_by_level` - Returns all referrals for an exclusive affiliate organized by level (1-5)
    
  2. Description
    - Level 1: Direct referrals of the affiliate
    - Level 2: Referrals of Level 1 users
    - Level 3: Referrals of Level 2 users
    - Level 4: Referrals of Level 3 users
    - Level 5: Referrals of Level 4 users
    
  3. Returns
    - User details including email, name, registration date, total deposits, trading volume
*/

CREATE OR REPLACE FUNCTION get_affiliate_network_by_level(
  p_affiliate_user_id uuid
)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  level int,
  referred_by_email text,
  registered_at timestamptz,
  total_deposits numeric,
  trading_volume numeric,
  is_active boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE network AS (
    -- Level 1: Direct referrals
    SELECT 
      up.user_id,
      1 as level,
      p_affiliate_user_id as referred_by_user_id
    FROM user_profiles up
    WHERE up.referred_by = (
      SELECT referral_code FROM user_profiles WHERE user_id = p_affiliate_user_id
    )
    
    UNION ALL
    
    -- Levels 2-5: Recursive referrals
    SELECT 
      up.user_id,
      n.level + 1 as level,
      n.user_id as referred_by_user_id
    FROM user_profiles up
    INNER JOIN network n ON up.referred_by = (
      SELECT referral_code FROM user_profiles WHERE user_id = n.user_id
    )
    WHERE n.level < 5
  )
  SELECT 
    n.user_id,
    au.email::text,
    up.full_name,
    up.username,
    n.level,
    referred_by_au.email::text as referred_by_email,
    up.created_at as registered_at,
    COALESCE((
      SELECT SUM(amount_usd)
      FROM crypto_deposits
      WHERE user_id = n.user_id AND status = 'completed'
    ), 0) as total_deposits,
    COALESCE(rs.total_volume, 0) as trading_volume,
    (au.last_sign_in_at > NOW() - INTERVAL '30 days') as is_active
  FROM network n
  JOIN auth.users au ON n.user_id = au.id
  JOIN user_profiles up ON n.user_id = up.user_id
  LEFT JOIN auth.users referred_by_au ON n.referred_by_user_id = referred_by_au.id
  LEFT JOIN referral_stats rs ON n.user_id = rs.user_id
  ORDER BY n.level, up.created_at DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_affiliate_network_by_level(uuid) TO authenticated;
