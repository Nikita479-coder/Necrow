/*
  # Fix Admin Users List Function
  
  1. Changes
    - Drop and recreate function with correct return types matching actual column types
    - Use varchar instead of text to match auth.users email column type
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS get_admin_users_list();

-- Recreate with correct types
CREATE OR REPLACE FUNCTION get_admin_users_list()
RETURNS TABLE (
  id uuid,
  email varchar,
  username text,
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
    up.kyc_status,
    up.kyc_level,
    up.created_at,
    COALESCE(SUM(w.balance::numeric), 0) as total_balance,
    COUNT(DISTINCT fp.position_id)::bigint as open_positions,
    COALESCE(SUM(fp.unrealized_pnl::numeric), 0) as unrealized_pnl
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallets w ON w.user_id = up.id AND w.currency = 'USDT'
  LEFT JOIN futures_positions fp ON fp.user_id = up.id AND fp.status = 'open'
  GROUP BY up.id, au.email, up.username, up.kyc_status, up.kyc_level, up.created_at
  ORDER BY up.created_at DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_users_list() TO authenticated;
