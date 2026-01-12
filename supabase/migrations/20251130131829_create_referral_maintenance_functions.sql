/*
  # Create Referral System Maintenance Functions
  
  1. New Functions
    - reset_monthly_earnings() - Reset all users' this_month_earnings to 0 at month start
    - update_30day_volumes() - Recalculate 30-day volumes based on actual trades
    - Both should be called via scheduled jobs/edge functions
  
  2. Purpose
    - Keep monthly earnings accurate
    - Keep 30-day volumes up to date
    - Maintain accurate VIP levels
*/

-- Function to reset monthly earnings (call at start of each month)
CREATE OR REPLACE FUNCTION reset_monthly_earnings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Reset all users' monthly earnings to 0
  UPDATE referral_stats
  SET 
    this_month_earnings = 0,
    updated_at = now()
  WHERE this_month_earnings > 0;
  
  -- Log the reset
  RAISE NOTICE 'Monthly earnings reset completed for % users', 
    (SELECT COUNT(*) FROM referral_stats WHERE updated_at = now());
END;
$$;

-- Function to recalculate 30-day volumes and update VIP levels
CREATE OR REPLACE FUNCTION update_30day_volumes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record record;
  v_volume_30d numeric;
  v_new_vip_level integer;
BEGIN
  -- For each user with referral stats
  FOR v_user_record IN 
    SELECT user_id FROM referral_stats
  LOOP
    -- Calculate actual 30-day volume from commissions
    SELECT COALESCE(SUM(trade_amount), 0) INTO v_volume_30d
    FROM referral_commissions
    WHERE referrer_id = v_user_record.user_id
      AND created_at >= now() - INTERVAL '30 days';
    
    -- Calculate new VIP level
    v_new_vip_level := calculate_vip_level(v_volume_30d);
    
    -- Update stats
    UPDATE referral_stats
    SET 
      total_volume_30d = v_volume_30d,
      vip_level = v_new_vip_level,
      updated_at = now()
    WHERE user_id = v_user_record.user_id
      AND (total_volume_30d != v_volume_30d OR vip_level != v_new_vip_level);
  END LOOP;
  
  RAISE NOTICE '30-day volumes updated for all users';
END;
$$;

-- Grant execute permissions (for edge functions/scheduled jobs)
GRANT EXECUTE ON FUNCTION reset_monthly_earnings() TO authenticated;
GRANT EXECUTE ON FUNCTION update_30day_volumes() TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION reset_monthly_earnings() IS 'Call this at the start of each month to reset monthly earnings';
COMMENT ON FUNCTION update_30day_volumes() IS 'Call this daily to keep 30-day volumes and VIP levels accurate';
