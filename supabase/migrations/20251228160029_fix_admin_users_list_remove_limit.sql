/*
  # Remove Limit from Admin Users List Function

  1. Changes
    - Remove LIMIT 50 from get_admin_users_list function
    - Allow pagination to be handled on the frontend
    - Function will now return all users for proper pagination

  2. Notes
    - Frontend pagination will control how many users are displayed per page
    - This allows admins to see all users in the system
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
  ORDER BY up.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_users_list() TO authenticated;