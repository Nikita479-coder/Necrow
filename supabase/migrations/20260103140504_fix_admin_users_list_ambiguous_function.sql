/*
  # Fix Admin Users List Ambiguous Function Call
  
  1. Problem
    - is_user_admin() has two overloads causing ambiguity
  
  2. Solution
    - Explicitly call the no-argument version
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
  -- Explicitly check admin status using JWT
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  IF NOT is_admin THEN
    -- Check staff status as fallback
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE user_id = auth.uid() AND is_active = true
    );
  END IF;
  
  IF NOT is_admin THEN
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
