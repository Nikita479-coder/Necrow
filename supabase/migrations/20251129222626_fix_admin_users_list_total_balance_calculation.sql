/*
  # Fix Admin Users List - Calculate Total Balance in USD
  
  1. Changes
    - Update get_admin_users_list function to calculate total balance across all currencies
    - Use get_wallet_balances function to get USD values
    - Include futures wallet in total balance calculation
  
  2. Notes
    - This will show accurate total balance including all crypto converted to USD
    - Includes main, assets, copy, and futures wallets
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
    (
      -- Calculate total balance from get_wallet_balances
      SELECT COALESCE(
        (result->>'main_balance')::numeric + 
        (result->>'assets_balance')::numeric + 
        (result->>'copy_balance')::numeric + 
        (result->>'futures_balance')::numeric,
        0
      )
      FROM get_wallet_balances(up.id) as result
    ) as total_balance,
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
