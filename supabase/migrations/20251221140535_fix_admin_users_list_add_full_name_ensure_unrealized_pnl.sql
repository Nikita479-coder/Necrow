/*
  # Fix Admin Users List - Add full_name and Ensure Unrealized P&L

  1. Changes
    - Update get_admin_users_list to include full_name field
    - Ensure unrealized_pnl is properly calculated from futures_positions
    - Fix any aggregation issues with GROUP BY

  2. Notes
    - full_name comes from user_profiles table
    - unrealized_pnl is summed from all open futures positions
    - Function uses SECURITY DEFINER to access auth.users
*/

DROP FUNCTION IF EXISTS get_admin_users_list();

CREATE OR REPLACE FUNCTION get_admin_users_list()
RETURNS TABLE (
  id uuid,
  email varchar,
  username text,
  full_name text,
  kyc_status text,
  kyc_level integer,
  created_at timestamptz,
  total_balance numeric,
  open_positions bigint,
  unrealized_pnl numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.id,
    au.email::varchar,
    COALESCE(up.username, 'No username') as username,
    up.full_name,
    up.kyc_status,
    up.kyc_level,
    up.created_at,
    calculate_total_portfolio_value_usd(up.id) as total_balance,
    COUNT(DISTINCT fp.position_id)::bigint as open_positions,
    COALESCE(SUM(fp.unrealized_pnl), 0)::numeric as unrealized_pnl
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN futures_positions fp ON fp.user_id = up.id AND fp.status = 'open'
  GROUP BY up.id, au.email, up.username, up.full_name, up.kyc_status, up.kyc_level, up.created_at
  ORDER BY up.created_at DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_users_list() TO authenticated;
