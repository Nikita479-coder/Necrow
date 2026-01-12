/*
  # Improve VIP Volume Tracking with True 30-Day Rolling Window

  1. Changes
    - Update calculate_user_vip_level to calculate volume from actual transactions
    - Ensure 30-day rolling window is properly calculated each time
    - Handle users with no recent activity (volume should decrease)
    
  2. Purpose
    - VIP levels properly downgrade when users stop trading
    - Volume is always accurately calculated from last 30 days
    - Scheduled job can recalculate all users including inactive ones
*/

-- Update calculate_user_vip_level to properly calculate from transactions
CREATE OR REPLACE FUNCTION calculate_user_vip_level(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_volume_30d numeric;
  v_level_record RECORD;
  v_futures_volume numeric := 0;
  v_swap_volume numeric := 0;
BEGIN
  -- Calculate futures trading volume from last 30 days
  -- Use margin_amount * leverage as the volume (as per business logic)
  SELECT COALESCE(SUM(fp.margin_amount * fp.leverage), 0)
  INTO v_futures_volume
  FROM futures_positions fp
  WHERE fp.user_id = p_user_id
    AND fp.opened_at >= NOW() - INTERVAL '30 days';

  -- Calculate swap trading volume from last 30 days
  -- Convert all swaps to USD equivalent
  SELECT COALESCE(SUM(
    CASE 
      WHEN so.to_currency = 'USDT' THEN so.to_amount
      WHEN so.from_currency = 'USDT' THEN so.from_amount
      ELSE so.to_amount * COALESCE(
        (SELECT mark_price FROM market_prices WHERE pair = so.to_currency || '/USDT' LIMIT 1),
        1
      )
    END
  ), 0)
  INTO v_swap_volume
  FROM swap_orders so
  WHERE so.user_id = p_user_id
    AND so.executed_at >= NOW() - INTERVAL '30 days'
    AND so.status = 'completed';

  -- Total 30-day volume
  v_volume_30d := v_futures_volume + v_swap_volume;

  -- Update or insert into user_volume_tracking
  INSERT INTO user_volume_tracking (user_id, volume_30d, last_updated)
  VALUES (p_user_id, v_volume_30d, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    volume_30d = v_volume_30d,
    last_updated = NOW();

  -- Find matching VIP level from vip_levels table
  SELECT * INTO v_level_record
  FROM vip_levels
  WHERE v_volume_30d >= min_volume_30d
    AND (max_volume_30d IS NULL OR v_volume_30d <= max_volume_30d)
  ORDER BY level_number DESC
  LIMIT 1;

  -- If no level found, default to VIP 1 (lowest tier)
  IF v_level_record.level_number IS NULL THEN
    SELECT * INTO v_level_record
    FROM vip_levels
    WHERE level_number = 1;
  END IF;

  -- Insert or update user VIP status
  INSERT INTO user_vip_status (
    user_id,
    current_level,
    volume_30d,
    commission_rate,
    rebate_rate,
    last_calculated_at
  ) VALUES (
    p_user_id,
    v_level_record.level_number,
    v_volume_30d,
    v_level_record.commission_rate,
    v_level_record.rebate_rate,
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    current_level = EXCLUDED.current_level,
    volume_30d = EXCLUDED.volume_30d,
    commission_rate = EXCLUDED.commission_rate,
    rebate_rate = EXCLUDED.rebate_rate,
    last_calculated_at = EXCLUDED.last_calculated_at,
    updated_at = NOW();
END;
$$;

-- Create a function to recalculate all users' VIP levels (for scheduled jobs)
CREATE OR REPLACE FUNCTION recalculate_all_vip_levels()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record RECORD;
  v_processed_count integer := 0;
  v_error_count integer := 0;
BEGIN
  -- Process all users, not just those with recent activity
  FOR v_user_record IN
    SELECT id FROM user_profiles
  LOOP
    BEGIN
      PERFORM calculate_user_vip_level(v_user_record.id);
      v_processed_count := v_processed_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      RAISE WARNING 'Error calculating VIP for user %: %', v_user_record.id, SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed', v_processed_count,
    'errors', v_error_count,
    'timestamp', NOW()
  );
END;
$$;