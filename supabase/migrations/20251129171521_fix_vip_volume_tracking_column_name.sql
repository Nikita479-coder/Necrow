/*
  # Fix VIP Volume Tracking - Correct Column Name

  1. Changes
    - Update all functions to use `transaction_type` instead of `type`
*/

-- Function to calculate user's 30-day trading volume (FIXED)
CREATE OR REPLACE FUNCTION calculate_user_30d_volume(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_volume numeric := 0;
  v_futures_volume numeric := 0;
  v_swap_volume numeric := 0;
BEGIN
  -- Calculate futures trading volume (last 30 days)
  SELECT COALESCE(SUM(
    CASE 
      WHEN transaction_type IN ('open_position', 'close_position') THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_futures_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND transaction_type IN ('open_position', 'close_position');

  -- Calculate swap trading volume (last 30 days)
  SELECT COALESCE(SUM(
    CASE 
      WHEN transaction_type = 'swap' THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_swap_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND transaction_type = 'swap';

  -- Total volume
  v_total_volume := v_futures_volume + v_swap_volume;

  RETURN v_total_volume;
END;
$$;

-- Function to update a specific user's VIP level (FIXED)
CREATE OR REPLACE FUNCTION update_user_vip_level(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_volume numeric;
  v_new_vip_level integer;
  v_all_time_volume numeric := 0;
BEGIN
  -- Calculate 30-day volume
  v_volume := calculate_user_30d_volume(p_user_id);
  
  -- Get VIP level for this volume
  v_new_vip_level := get_vip_level_for_volume(v_volume);

  -- Calculate all-time volume
  SELECT COALESCE(SUM(
    CASE 
      WHEN transaction_type IN ('open_position', 'close_position', 'swap') THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_all_time_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type IN ('open_position', 'close_position', 'swap');

  -- Update or insert referral_stats
  INSERT INTO referral_stats (
    user_id,
    vip_level,
    total_volume_30d,
    total_volume_all_time,
    updated_at
  )
  VALUES (
    p_user_id,
    v_new_vip_level,
    v_volume,
    v_all_time_volume,
    NOW()
  )
  ON CONFLICT (user_id) 
  DO UPDATE SET
    vip_level = v_new_vip_level,
    total_volume_30d = v_volume,
    total_volume_all_time = v_all_time_volume,
    updated_at = NOW();
END;
$$;

-- Trigger to update VIP level after transaction (FIXED)
CREATE OR REPLACE FUNCTION trigger_update_vip_after_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.transaction_type IN ('open_position', 'close_position', 'swap') THEN
    PERFORM update_user_vip_level(NEW.user_id);
  END IF;
  
  RETURN NEW;
END;
$$;