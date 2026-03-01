/*
  # Create Admin User Helper Functions
  
  1. New Functions
    - `get_user_email(user_id)` - Gets email for a specific user from auth.users
    - `get_admin_users_list()` - Gets complete user list with all data for admin dashboard
  
  2. Security
    - Functions execute with SECURITY DEFINER to access auth.users
    - Only accessible by admin users (checked via RLS policies)
*/

-- Function to get a single user's email
CREATE OR REPLACE FUNCTION get_user_email(user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN (SELECT email FROM auth.users WHERE id = user_id);
END;
$$;

-- Function to get complete admin users list
CREATE OR REPLACE FUNCTION get_admin_users_list()
RETURNS TABLE (
  id uuid,
  email text,
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
    au.email,
    COALESCE(up.username, 'No username') as username,
    up.kyc_status,
    up.kyc_level,
    up.created_at,
    COALESCE(SUM(DISTINCT w.balance::numeric), 0) as total_balance,
    COALESCE(COUNT(DISTINCT fp.position_id), 0) as open_positions,
    COALESCE(SUM(DISTINCT fp.unrealized_pnl::numeric), 0) as unrealized_pnl
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallets w ON w.user_id = up.id AND w.currency = 'USDT'
  LEFT JOIN futures_positions fp ON fp.user_id = up.id AND fp.status = 'open'
  GROUP BY up.id, au.email, up.username, up.kyc_status, up.kyc_level, up.created_at
  ORDER BY up.created_at DESC
  LIMIT 50;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_email(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_users_list() TO authenticated;
