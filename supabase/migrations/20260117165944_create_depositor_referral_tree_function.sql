/*
  # Create Depositor Referral Tree Function
  
  1. New Functions
    - `get_depositor_referral_tree(root_user_id, include_non_depositors)` - Returns hierarchical tree of referrals filtered by depositors
      - Uses recursive CTE to traverse referral chain up to 10 levels
      - Joins with crypto_deposits to get deposit totals
      - Returns: user_id, email, full_name, parent_id, level, total_deposits, deposit_count, first_deposit_date, last_deposit_date, has_deposits
    
  2. Purpose
    - Allows admin to visualize referral tree showing only users who have made deposits
    - Shows deposit amounts aggregated per user
    - Supports drilling down into any user's sub-tree
    
  3. Security
    - Function is SECURITY DEFINER to access user data
    - Restricted to authenticated users (admin check in calling code)
*/

-- Create the depositor referral tree function
CREATE OR REPLACE FUNCTION get_depositor_referral_tree(
  p_root_user_id uuid,
  p_include_non_depositors boolean DEFAULT false,
  p_min_deposit_amount numeric DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  parent_id uuid,
  level integer,
  total_deposits numeric,
  deposit_count bigint,
  first_deposit_date timestamptz,
  last_deposit_date timestamptz,
  has_deposits boolean,
  referral_code text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    -- Base case: the root user
    SELECT 
      up.id AS user_id,
      up.id AS parent_id,
      0 AS level
    FROM user_profiles up
    WHERE up.id = p_root_user_id
    
    UNION ALL
    
    -- Recursive case: find all users referred by current level
    SELECT 
      up.id AS user_id,
      up.referred_by AS parent_id,
      rt.level + 1 AS level
    FROM user_profiles up
    INNER JOIN referral_tree rt ON up.referred_by = rt.user_id
    WHERE rt.level < 10  -- Limit to 10 levels deep
  ),
  -- Calculate deposit stats for each user
  deposit_stats AS (
    SELECT 
      cd.user_id,
      COALESCE(SUM(cd.outcome_amount), 0) AS total_deposits,
      COUNT(cd.payment_id) AS deposit_count,
      MIN(cd.completed_at) AS first_deposit_date,
      MAX(cd.completed_at) AS last_deposit_date
    FROM crypto_deposits cd
    WHERE cd.status IN ('finished', 'confirmed', 'partially_paid')
    GROUP BY cd.user_id
  )
  SELECT 
    rt.user_id,
    au.email::text,
    up.full_name,
    up.username,
    CASE WHEN rt.level = 0 THEN NULL ELSE rt.parent_id END AS parent_id,
    rt.level,
    COALESCE(ds.total_deposits, 0) AS total_deposits,
    COALESCE(ds.deposit_count, 0) AS deposit_count,
    ds.first_deposit_date,
    ds.last_deposit_date,
    (COALESCE(ds.total_deposits, 0) > 0) AS has_deposits,
    up.referral_code,
    up.created_at
  FROM referral_tree rt
  INNER JOIN user_profiles up ON up.id = rt.user_id
  LEFT JOIN auth.users au ON au.id = rt.user_id
  LEFT JOIN deposit_stats ds ON ds.user_id = rt.user_id
  WHERE 
    -- Filter based on include_non_depositors flag
    (p_include_non_depositors = true OR COALESCE(ds.total_deposits, 0) > 0 OR rt.level = 0)
    -- Filter by minimum deposit amount (root user always included)
    AND (rt.level = 0 OR COALESCE(ds.total_deposits, 0) >= p_min_deposit_amount)
  ORDER BY rt.level, ds.total_deposits DESC NULLS LAST;
END;
$$;

-- Create a function to get tree statistics
CREATE OR REPLACE FUNCTION get_depositor_tree_stats(p_root_user_id uuid)
RETURNS TABLE (
  total_users bigint,
  total_depositors bigint,
  total_deposit_volume numeric,
  avg_deposit_per_user numeric,
  max_depth integer,
  level_1_depositors bigint,
  level_1_volume numeric,
  level_2_depositors bigint,
  level_2_volume numeric,
  level_3_depositors bigint,
  level_3_volume numeric,
  level_4_depositors bigint,
  level_4_volume numeric,
  level_5_plus_depositors bigint,
  level_5_plus_volume numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH tree_data AS (
    SELECT * FROM get_depositor_referral_tree(p_root_user_id, true, 0)
    WHERE level > 0  -- Exclude root user from stats
  )
  SELECT 
    COUNT(*)::bigint AS total_users,
    COUNT(*) FILTER (WHERE td.has_deposits)::bigint AS total_depositors,
    COALESCE(SUM(td.total_deposits), 0) AS total_deposit_volume,
    CASE 
      WHEN COUNT(*) FILTER (WHERE td.has_deposits) > 0 
      THEN ROUND(SUM(td.total_deposits) / COUNT(*) FILTER (WHERE td.has_deposits), 2)
      ELSE 0 
    END AS avg_deposit_per_user,
    COALESCE(MAX(td.level), 0) AS max_depth,
    -- Level 1 stats
    COUNT(*) FILTER (WHERE td.level = 1 AND td.has_deposits)::bigint AS level_1_depositors,
    COALESCE(SUM(td.total_deposits) FILTER (WHERE td.level = 1), 0) AS level_1_volume,
    -- Level 2 stats
    COUNT(*) FILTER (WHERE td.level = 2 AND td.has_deposits)::bigint AS level_2_depositors,
    COALESCE(SUM(td.total_deposits) FILTER (WHERE td.level = 2), 0) AS level_2_volume,
    -- Level 3 stats
    COUNT(*) FILTER (WHERE td.level = 3 AND td.has_deposits)::bigint AS level_3_depositors,
    COALESCE(SUM(td.total_deposits) FILTER (WHERE td.level = 3), 0) AS level_3_volume,
    -- Level 4 stats
    COUNT(*) FILTER (WHERE td.level = 4 AND td.has_deposits)::bigint AS level_4_depositors,
    COALESCE(SUM(td.total_deposits) FILTER (WHERE td.level = 4), 0) AS level_4_volume,
    -- Level 5+ stats
    COUNT(*) FILTER (WHERE td.level >= 5 AND td.has_deposits)::bigint AS level_5_plus_depositors,
    COALESCE(SUM(td.total_deposits) FILTER (WHERE td.level >= 5), 0) AS level_5_plus_volume
  FROM tree_data td;
END;
$$;

-- Create a function to search for users to view their tree
CREATE OR REPLACE FUNCTION search_users_for_tree(p_search_term text, p_limit integer DEFAULT 20)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  total_referrals bigint,
  has_depositors boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id AS user_id,
    au.email::text,
    up.full_name,
    up.username,
    up.referral_code,
    COALESCE(rs.total_referrals, 0)::bigint AS total_referrals,
    EXISTS (
      SELECT 1 
      FROM user_profiles ref 
      INNER JOIN crypto_deposits cd ON cd.user_id = ref.id
      WHERE ref.referred_by = up.id 
      AND cd.status IN ('finished', 'confirmed', 'partially_paid')
    ) AS has_depositors
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  WHERE 
    up.full_name ILIKE '%' || p_search_term || '%'
    OR up.username ILIKE '%' || p_search_term || '%'
    OR up.referral_code ILIKE '%' || p_search_term || '%'
    OR au.email ILIKE '%' || p_search_term || '%'
  ORDER BY COALESCE(rs.total_referrals, 0) DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_depositor_referral_tree(uuid, boolean, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION get_depositor_tree_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION search_users_for_tree(text, integer) TO authenticated;
