/*
  # Fix get_exclusive_affiliate_referrals Function

  ## Issue
  The function may not be returning results due to permission issues with get_user_email
  or because there are legitimately no referrals.

  ## Changes
  1. Add better error handling
  2. Ensure the function can fetch emails properly
  3. Add grants for proper execution
*/

-- Recreate the function with better error handling
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
  -- Get enrollment date
  SELECT created_at INTO v_enrolled_at
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_id;

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
      (SELECT email FROM auth.users WHERE id = rt.id),
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO service_role;
