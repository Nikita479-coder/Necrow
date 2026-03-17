/*
  # Fix get_exclusive_affiliate_referrals Ambiguous Column

  ## Issue
  The function has an ambiguous reference to user_id that could refer to
  either the return table column or the table column.

  ## Solution
  Ensure all column references are properly qualified with table aliases.
*/

DROP FUNCTION IF EXISTS get_exclusive_affiliate_referrals(uuid);

CREATE OR REPLACE FUNCTION get_exclusive_affiliate_referrals(p_affiliate_id uuid)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  level integer,
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
  SELECT created_at INTO v_enrolled_at
  FROM exclusive_affiliates
  WHERE exclusive_affiliates.user_id = p_affiliate_id;
  
  IF v_enrolled_at IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    SELECT 
      up.id,
      up.full_name,
      up.username,
      up.referred_by,
      up.created_at,
      1 as level
    FROM user_profiles up
    WHERE up.referred_by = p_affiliate_id
    
    UNION ALL
    
    SELECT 
      up.id,
      up.full_name,
      up.username,
      up.referred_by,
      up.created_at,
      rt.level + 1
    FROM user_profiles up
    JOIN referral_tree rt ON up.referred_by = rt.id
    WHERE rt.level < 10
  )
  SELECT 
    rt.id,
    get_user_email(rt.id),
    rt.full_name,
    rt.username,
    rt.level,
    rt.created_at,
    COALESCE(rs.total_deposits, 0),
    COALESCE(rs.total_volume, 0),
    (rt.created_at >= v_enrolled_at)
  FROM referral_tree rt
  LEFT JOIN referral_stats rs ON rs.user_id = rt.id
  ORDER BY rt.level, rt.created_at DESC;
END;
$$;
