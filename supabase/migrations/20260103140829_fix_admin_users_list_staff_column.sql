/*
  # Fix Admin Users List Staff Column Reference
  
  1. Fix
    - admin_staff uses 'id' not 'user_id'
*/

DROP FUNCTION IF EXISTS get_admin_users_list();

CREATE OR REPLACE FUNCTION get_admin_users_list()
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
  referral_count integer
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
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
    COALESCE(uvs.current_level, 'None')::text,
    (up.referred_by IS NOT NULL)::boolean,
    COALESCE(rs.total_referrals, 0)::integer
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallet_totals wt ON wt.user_id = up.id
  LEFT JOIN position_stats ps ON ps.user_id = up.id
  LEFT JOIN user_vip_status uvs ON uvs.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  ORDER BY up.created_at DESC;
END;
$$;
