/*
  # Fix Admin Stats to Use Existing Helper Function

  1. Changes
    - Update get_admin_stats_v2 to use the is_admin() helper function
    - This avoids RLS circular dependency issues
*/

CREATE OR REPLACE FUNCTION get_admin_stats_v2()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users int;
  v_active_traders int;
  v_pending_kyc int;
  v_at_risk int;
  v_volume_24h numeric;
  v_pnl_24h numeric;
  v_yesterday timestamptz;
BEGIN
  -- Check if current user is admin using the helper function
  IF NOT is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Set yesterday timestamp
  v_yesterday := NOW() - INTERVAL '24 hours';

  -- Get total users count
  SELECT COUNT(*) INTO v_total_users
  FROM user_profiles;

  -- Get active traders (distinct users with open positions)
  SELECT COUNT(DISTINCT user_id) INTO v_active_traders
  FROM futures_positions
  WHERE status = 'open';

  -- Get pending KYC count
  SELECT COUNT(*) INTO v_pending_kyc
  FROM user_profiles
  WHERE kyc_status = 'pending';

  -- Get at-risk positions count
  SELECT COUNT(*) INTO v_at_risk
  FROM liquidation_queue;

  -- Get 24h trading volume
  SELECT COALESCE(SUM(quantity::numeric * price::numeric), 0) INTO v_volume_24h
  FROM trades
  WHERE executed_at >= v_yesterday;

  -- Get 24h P&L
  SELECT COALESCE(SUM(realized_pnl::numeric), 0) INTO v_pnl_24h
  FROM futures_positions
  WHERE closed_at >= v_yesterday;

  -- Return as JSON
  RETURN json_build_object(
    'total_users', v_total_users,
    'active_traders', v_active_traders,
    'pending_kyc', v_pending_kyc,
    'at_risk_positions', v_at_risk,
    'volume_24h', v_volume_24h,
    'pnl_24h', v_pnl_24h
  );
END;
$$;
