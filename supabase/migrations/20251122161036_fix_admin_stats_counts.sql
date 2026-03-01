/*
  # Fix Admin Dashboard Stats Counts

  1. New Functions
    - `get_admin_stats` - Returns all admin dashboard statistics in one call
    
  2. Changes
    - Creates a SECURITY DEFINER function to bypass RLS for admin stats
    - Returns total users, active traders, pending KYC, at-risk positions, 24h volume, and 24h P&L
*/

-- Create function to get all admin stats
CREATE OR REPLACE FUNCTION get_admin_stats()
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
  -- Check if user is admin
  IF NOT (SELECT COALESCE((auth.jwt()->>'app_metadata')::json->>'is_admin', 'false')::boolean) THEN
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
