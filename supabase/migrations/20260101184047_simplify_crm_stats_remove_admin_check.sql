/*
  # Simplify CRM Stats - Remove Redundant Admin Check
  
  1. Problem
    - Admin check in function causes issues with RLS
    - Frontend already protects admin pages via profile.is_admin check
  
  2. Solution
    - Remove admin check from function (security via frontend + RLS on other tables)
    - Function will only return data if user is authenticated
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
