/*
  # Fix Admin Users List - Remove 1000 Row Limit

  1. Problem
    - Supabase default limit of 1000 rows was preventing all users from being loaded
    - Admin dashboard showed "1000 users" instead of actual 1077+ users

  2. Solution
    - Add pagination support to get_admin_users_list function
    - Create a separate count function for accurate totals
    - Remove implicit limits

  3. Changes
    - Updated get_admin_users_list to accept offset/limit parameters
    - Created get_admin_users_count for accurate total count
*/

-- Drop the old function
DROP FUNCTION IF EXISTS get_admin_users_list();

-- Create paginated version
CREATE OR REPLACE FUNCTION get_admin_users_list(
  p_offset integer DEFAULT 0,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  email text,
  username text,
  full_name text,
  kyc_status text,
  kyc_level integer,
  created_at timestamptz,
  total_balance numeric,
  open_positions bigint,
  unrealized_pnl numeric,
  vip_tier text,
  has_referrer boolean,
  referral_count integer,
  total_deposits numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  is_admin boolean;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);

  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND is_active = true
    );
  END IF;

  IF NOT is_admin THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH wallet_totals AS (
    SELECT w.user_id, SUM(w.balance) as total
    FROM wallets w
    GROUP BY w.user_id
  ),
  position_stats AS (
    SELECT 
      fp.user_id,
      COUNT(*) as pos_count,
      SUM(fp.unrealized_pnl) as total_pnl
    FROM futures_positions fp
    WHERE fp.status = 'open'
    GROUP BY fp.user_id
  ),
  deposit_totals AS (
    SELECT 
      cd.user_id,
      SUM(COALESCE(cd.actually_paid, 0)) as total
    FROM crypto_deposits cd
    WHERE cd.status IN ('completed', 'confirmed', 'finished', 'partially_paid')
    GROUP BY cd.user_id
  )
  SELECT 
    up.id,
    COALESCE(au.email, 'N/A')::text,
    up.username::text,
    up.full_name::text,
    COALESCE(up.kyc_status, 'none')::text,
    COALESCE(up.kyc_level, 0)::integer,
    up.created_at,
    COALESCE(wt.total, 0)::numeric,
    COALESCE(ps.pos_count, 0)::bigint,
    COALESCE(ps.total_pnl, 0)::numeric,
    COALESCE(get_vip_tier_name(uvs.current_level), 'VIP 1')::text as vip_tier,
    (up.referred_by IS NOT NULL)::boolean,
    COALESCE(rs.total_referrals, 0)::integer,
    COALESCE(dt.total, 0)::numeric as total_deposits
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallet_totals wt ON wt.user_id = up.id
  LEFT JOIN position_stats ps ON ps.user_id = up.id
  LEFT JOIN user_vip_status uvs ON uvs.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  LEFT JOIN deposit_totals dt ON dt.user_id = up.id
  ORDER BY up.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Create a separate count function for accurate totals
CREATE OR REPLACE FUNCTION get_admin_users_total_count()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  is_admin boolean;
  v_count bigint;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);

  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND is_active = true
    );
  END IF;

  IF NOT is_admin THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*) INTO v_count FROM user_profiles;
  RETURN v_count;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_admin_users_list(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_users_total_count() TO authenticated;
