/*
  # Update Admin Users List to Show Total Portfolio Value
  
  1. Changes
    - Update get_admin_users_list to use calculate_total_portfolio_value_usd
    - This will show the total USD value including all crypto holdings
    - Matches what users see on their wallet page
  
  2. Notes
    - Admin list shows total portfolio value in USD
    - Individual user detail pages will show the breakdown by wallet and currency
*/

DROP FUNCTION IF EXISTS get_admin_users_list();

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
    calculate_total_portfolio_value_usd(up.id) as total_balance,
    COUNT(DISTINCT fp.position_id)::bigint as open_positions,
    COALESCE(SUM(fp.unrealized_pnl::numeric), 0) as unrealized_pnl
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN futures_positions fp ON fp.user_id = up.id AND fp.status = 'open'
  GROUP BY up.id, au.email, up.username, up.kyc_status, up.kyc_level, up.created_at
  ORDER BY up.created_at DESC
  LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION get_admin_users_list() TO authenticated;
