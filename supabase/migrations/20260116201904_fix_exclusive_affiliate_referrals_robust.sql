/*
  # Fix Exclusive Affiliate Referrals Function - Robust Version

  ## Issue
  The get_exclusive_affiliate_referrals function may be failing silently or not finding
  referrals due to:
  1. Issues with get_user_email function
  2. Missing referral relationships in user_profiles
  3. The referrals counter in stats table is out of sync with actual referrals

  ## Changes
  1. Make the function more robust with better error handling
  2. Remove dependency on get_user_email which might fail
  3. Add debug logging capabilities
  4. Fix any issues with the recursive CTE
*/

-- Drop and recreate the function with robust error handling
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
  v_referral_count integer;
BEGIN
  -- Get enrollment date
  SELECT created_at INTO v_enrolled_at
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_id;

  -- If affiliate not found, return empty
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
      AND up.id != p_affiliate_id  -- Exclude self-referral

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
    INNER JOIN referral_tree rt ON up.referred_by = rt.id
    WHERE rt.level < 10
      AND up.id != p_affiliate_id  -- Exclude self-referral
      AND up.id NOT IN (SELECT id FROM referral_tree)  -- Prevent cycles
  )
  SELECT
    rt.id as user_id,
    COALESCE(
      (SELECT au.email FROM auth.users au WHERE au.id = rt.id LIMIT 1),
      'hidden@email.com'
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
  ORDER BY rt.level ASC, rt.created_at DESC;
END;
$$;

-- Ensure proper grants
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_exclusive_affiliate_referrals(uuid) TO service_role;

-- Create a diagnostic function to check referral relationships
CREATE OR REPLACE FUNCTION debug_exclusive_affiliate_network(p_affiliate_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_enrolled_at timestamptz;
  v_direct_count integer;
  v_stats_count integer;
BEGIN
  -- Check if affiliate exists
  SELECT created_at INTO v_enrolled_at
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_id;

  IF v_enrolled_at IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'Affiliate not found',
      'affiliate_id', p_affiliate_id
    );
  END IF;

  -- Count direct referrals
  SELECT COUNT(*) INTO v_direct_count
  FROM user_profiles
  WHERE referred_by = p_affiliate_id;

  -- Get stats count
  SELECT COALESCE(level_1_count, 0) INTO v_stats_count
  FROM exclusive_affiliate_network_stats
  WHERE affiliate_id = p_affiliate_id;

  -- Build result
  v_result := jsonb_build_object(
    'affiliate_id', p_affiliate_id,
    'enrolled_at', v_enrolled_at,
    'direct_referrals_count', v_direct_count,
    'stats_level_1_count', v_stats_count,
    'match', (v_direct_count = v_stats_count)
  );

  -- Add sample referrals
  v_result := v_result || jsonb_build_object(
    'sample_referrals',
    (SELECT jsonb_agg(
      jsonb_build_object(
        'id', id,
        'full_name', full_name,
        'username', username,
        'created_at', created_at,
        'referred_by', referred_by
      )
    )
    FROM (
      SELECT id, full_name, username, created_at, referred_by
      FROM user_profiles
      WHERE referred_by = p_affiliate_id
      LIMIT 5
    ) sample)
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_exclusive_affiliate_network(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_exclusive_affiliate_network(uuid) TO service_role;
