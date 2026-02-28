/*
  # Fix Ambiguous Column Reference in Referral Function

  ## Issue
  The function has an ambiguous column reference because:
  1. The RETURN TABLE defines `user_id` as a column
  2. The exclusive_affiliates table also has a `user_id` column
  3. This causes "column reference user_id is ambiguous" error

  ## Solution
  Use proper table aliases in the WHERE clause to disambiguate the columns.
*/

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
  -- Get enrollment date (use table alias to avoid ambiguity)
  SELECT ea.created_at INTO v_enrolled_at
  FROM exclusive_affiliates ea
  WHERE ea.user_id = p_affiliate_id;

  -- If not found, return empty
  IF v_enrolled_at IS NULL THEN
    RETURN;
  END IF;

  -- Return all referrals in the network (up to 10 levels deep)
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    -- Level 1: Direct referrals
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

    -- Levels 2-10: Indirect referrals
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
    rt.id as user_id,
    COALESCE(
      (SELECT au.email FROM auth.users au WHERE au.id = rt.id),
      get_user_email(rt.id),
      'email-hidden'
    ) as email,
    rt.full_name,
    rt.username,
    rt.level,
    rt.created_at as registered_at,
    COALESCE(rs.total_deposits, 0) as total_deposits,
    COALESCE(rs.total_volume, 0) as trading_volume,
    (rt.created_at >= v_enrolled_at) as eligible
  FROM referral_tree rt
  LEFT JOIN referral_stats rs ON rs.user_id = rt.id
  ORDER BY rt.level, rt.created_at DESC;
END;
$$;

-- Ensure proper grants
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO anon;
