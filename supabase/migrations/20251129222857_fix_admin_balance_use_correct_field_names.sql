/*
  # Fix Admin Users List - Use Correct Field Names
  
  1. Changes
    - Update to use correct field names from get_wallet_balances
    - Add manual calculation for all wallet types since get_wallet_balances only returns main and futures
    - Convert crypto to USD using a simple calculation (needs price data)
  
  2. Notes
    - For now, we'll sum all USDT across all wallet types plus futures balance
    - Future enhancement: convert all crypto to USD value
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
      -- Sum all USDT from spot wallets
      COALESCE((
        SELECT SUM(balance::numeric)
        FROM wallets w
        WHERE w.user_id = up.id AND w.currency = 'USDT'
      ), 0) +
      -- Add futures wallet total
      COALESCE((
        SELECT available_balance::numeric + locked_balance::numeric
        FROM futures_margin_wallets fmw
        WHERE fmw.user_id = up.id
      ), 0)
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
