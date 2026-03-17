/*
  # Fix CRM Stats with Direct Admin Check
  
  1. Problem
    - Complex admin permission check failing due to RLS interactions
    - Function returns zeros for authenticated admin users
  
  2. Solution
    - Simplify admin check to directly query user_profiles
    - Use explicit SECURITY DEFINER with stable search_path
*/

CREATE OR REPLACE FUNCTION get_crm_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_stats json;
  v_user_id uuid;
  v_is_admin boolean := false;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
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
  
  SELECT COALESCE(is_admin, false) INTO v_is_admin
  FROM user_profiles 
  WHERE id = v_user_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    IF COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN 
      v_is_admin := true; 
    END IF;
  END IF;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    SELECT EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE id = v_user_id AND is_active = true
    ) INTO v_is_admin;
  END IF;
  
  IF NOT COALESCE(v_is_admin, false) THEN
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
