/*
  # Fix Admin Permission Check for Null Auth Context
  
  1. Problem
    - check_admin_permission returns false when auth.uid() is NULL
    - This happens with service role calls or certain RPC contexts
    - Causes get_crm_dashboard_stats to return all zeros
  
  2. Solution
    - Handle NULL auth.uid() gracefully
    - Check user_profiles.is_admin using a security definer approach
*/

CREATE OR REPLACE FUNCTION check_admin_permission(p_permission_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  IF COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN 
    RETURN true; 
  END IF;
  
  SELECT is_admin INTO v_is_admin
  FROM user_profiles 
  WHERE id = v_user_id;
  
  IF COALESCE(v_is_admin, false) THEN
    RETURN true;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM admin_staff s 
    JOIN admin_role_permissions rp ON s.role_id = rp.role_id 
    JOIN admin_permissions p ON rp.permission_id = p.id 
    WHERE s.id = v_user_id 
    AND s.is_active = true 
    AND p.code = p_permission_code
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_crm_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats json;
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NOT NULL THEN
    IF COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN 
      v_is_admin := true; 
    ELSE
      SELECT is_admin INTO v_is_admin FROM user_profiles WHERE id = v_user_id;
      v_is_admin := COALESCE(v_is_admin, false);
    END IF;
    
    IF NOT v_is_admin THEN
      SELECT EXISTS (
        SELECT 1 FROM admin_staff s 
        JOIN admin_role_permissions rp ON s.role_id = rp.role_id 
        JOIN admin_permissions p ON rp.permission_id = p.id 
        WHERE s.id = v_user_id AND s.is_active = true AND p.code = 'view_users'
      ) INTO v_is_admin;
    END IF;
  END IF;
  
  IF NOT v_is_admin THEN
    RETURN json_build_object(
      'totalUsers', 0,
      'activeUsers24h', 0,
      'activeUsers7d', 0,
      'newUsers24h', 0,
      'newUsers7d', 0,
      'kycPending', 0,
      'kycVerified', 0,
      'totalDeposits24h', 0,
      'totalWithdrawals24h', 0,
      'totalVolume24h', 0,
      'totalFees24h', 0,
      'openSupportTickets', 0,
      'avgResponseTime', 0,
      'vipBreakdown', '{}'::json
    );
  END IF;

  SELECT json_build_object(
    'totalUsers', (SELECT COUNT(*) FROM user_profiles),
    'activeUsers24h', COALESCE((
      SELECT COUNT(DISTINCT user_id) FROM user_sessions 
      WHERE last_activity > now() - interval '24 hours'
    ), 0),
    'activeUsers7d', COALESCE((
      SELECT COUNT(DISTINCT user_id) FROM user_sessions 
      WHERE last_activity > now() - interval '7 days'
    ), 0),
    'newUsers24h', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE created_at > now() - interval '24 hours'
    ),
    'newUsers7d', (
      SELECT COUNT(*) FROM user_profiles 
      WHERE created_at > now() - interval '7 days'
    ),
    'kycPending', (
      SELECT COUNT(*) FROM user_profiles WHERE kyc_status = 'pending'
    ),
    'kycVerified', (
      SELECT COUNT(*) FROM user_profiles WHERE kyc_status = 'verified'
    ),
    'totalDeposits24h', COALESCE((
      SELECT SUM(amount::numeric) FROM transactions 
      WHERE transaction_type = 'deposit' AND created_at > now() - interval '24 hours'
    ), 0),
    'totalWithdrawals24h', COALESCE((
      SELECT SUM(amount::numeric) FROM transactions 
      WHERE transaction_type = 'withdrawal' AND created_at > now() - interval '24 hours'
    ), 0),
    'totalVolume24h', COALESCE((
      SELECT SUM(size::numeric * entry_price::numeric) FROM futures_positions 
      WHERE opened_at > now() - interval '24 hours'
    ), 0),
    'totalFees24h', COALESCE((
      SELECT SUM(fee_amount::numeric) FROM fee_collections 
      WHERE created_at > now() - interval '24 hours'
    ), 0),
    'openSupportTickets', COALESCE((
      SELECT COUNT(*) FROM support_tickets WHERE status = 'open'
    ), 0),
    'avgResponseTime', 0,
    'vipBreakdown', COALESCE((
      SELECT json_object_agg(COALESCE(current_tier, 'None'), cnt)
      FROM (
        SELECT current_tier, COUNT(*) as cnt
        FROM vip_tier_tracking
        GROUP BY current_tier
      ) vb
    ), '{}'::json)
  ) INTO v_stats;

  RETURN v_stats;
END;
$$;
