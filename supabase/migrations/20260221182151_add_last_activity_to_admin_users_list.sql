/*
  # Add last_activity from user_sessions to admin users list

  1. Changes
    - Adds `last_activity` column from `user_sessions` table to the return type
    - This provides reliable "last seen" timestamps based on actual heartbeat data
    - Falls back to `last_sign_in_at` from auth.users if no session exists

  2. Notes
    - `user_sessions.last_activity` is updated every 15 seconds via heartbeat
    - Much more reliable than `auth.users.last_sign_in_at` which may be null
*/

DROP FUNCTION IF EXISTS get_admin_users_list(int, int);

CREATE FUNCTION get_admin_users_list(
  p_offset int DEFAULT 0,
  p_limit int DEFAULT 500
)
RETURNS TABLE(
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
  total_deposits numeric,
  last_sign_in_at timestamptz,
  last_activity timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_admin boolean;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);

  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND admin_staff.is_active = true
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
    COALESCE(dt.total, 0)::numeric as total_deposits,
    au.last_sign_in_at,
    us.last_activity
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallet_totals wt ON wt.user_id = up.id
  LEFT JOIN position_stats ps ON ps.user_id = up.id
  LEFT JOIN user_vip_status uvs ON uvs.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  LEFT JOIN deposit_totals dt ON dt.user_id = up.id
  LEFT JOIN user_sessions us ON us.user_id = up.id
  ORDER BY up.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
