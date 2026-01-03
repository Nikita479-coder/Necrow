/*
  # Add Referral Info to Admin Users List
  
  1. Changes
    - Add has_referrer flag (whether user was referred by someone)
    - Add referral_count (number of people this user has referred)
  
  2. Purpose
    - Enable filtering users by referral status in admin dashboard
*/

-- Drop existing function first
DROP FUNCTION IF EXISTS get_admin_users_list();

-- Recreate with new return type
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
BEGIN
  IF NOT public.is_user_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    up.id,
    COALESCE(au.email, 'N/A')::text as email,
    up.username::text,
    up.full_name::text,
    COALESCE(up.kyc_status, 'none')::text as kyc_status,
    COALESCE(up.kyc_level, 0)::integer as kyc_level,
    up.created_at,
    COALESCE((
      SELECT SUM(w.balance)
      FROM wallets w
      WHERE w.user_id = up.id
    ), 0)::numeric as total_balance,
    COALESCE((
      SELECT COUNT(*)
      FROM futures_positions fp
      WHERE fp.user_id = up.id AND fp.status = 'open'
    ), 0)::bigint as open_positions,
    COALESCE((
      SELECT SUM(fp.unrealized_pnl)
      FROM futures_positions fp
      WHERE fp.user_id = up.id AND fp.status = 'open'
    ), 0)::numeric as unrealized_pnl,
    COALESCE(uvs.current_level, 'None')::text as vip_tier,
    (up.referred_by IS NOT NULL)::boolean as has_referrer,
    COALESCE(rs.total_referrals, 0)::integer as referral_count
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN user_vip_status uvs ON uvs.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  ORDER BY up.created_at DESC;
END;
$$;
