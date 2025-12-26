/*
  # VIP Level and Trading Volume Tracking System

  1. New Functions
    - `calculate_user_30d_volume` - Calculate user's trading volume from last 30 days
    - `update_user_vip_level` - Update VIP level based on 30-day volume
    - `update_all_vip_levels` - Batch update all user VIP levels (scheduled)

  2. Changes
    - Automatically track volume from transactions
    - Update VIP level when volume changes
    - Support for futures, swaps, and all trading activities

  3. Security
    - Functions use SECURITY DEFINER for proper access
*/

-- Function to calculate user's 30-day trading volume
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
      WHEN type IN ('open_position', 'close_position') THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_futures_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND type IN ('open_position', 'close_position');

  -- Calculate swap trading volume (last 30 days)
  SELECT COALESCE(SUM(
    CASE 
      WHEN type = 'swap' THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_swap_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND type = 'swap';

  -- Total volume
  v_total_volume := v_futures_volume + v_swap_volume;

  RETURN v_total_volume;
END;
$$;

-- Function to determine VIP level based on volume
CREATE OR REPLACE FUNCTION get_vip_level_for_volume(p_volume numeric)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_volume >= 25000001 THEN
    RETURN 6; -- Diamond Elite
  ELSIF p_volume >= 2500001 THEN
    RETURN 5; -- Top-tier
  ELSIF p_volume >= 500001 THEN
    RETURN 4; -- Advanced
  ELSIF p_volume >= 100001 THEN
    RETURN 3; -- Balanced
  ELSIF p_volume >= 10001 THEN
    RETURN 2; -- Moderate
  ELSE
    RETURN 1; -- Entry
  END IF;
END;
$$;

-- Function to update a specific user's VIP level
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
      WHEN type IN ('open_position', 'close_position', 'swap') THEN ABS(amount)
      ELSE 0
    END
  ), 0)
  INTO v_all_time_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND type IN ('open_position', 'close_position', 'swap');

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

-- Function to update all users' VIP levels (for scheduled execution)
CREATE OR REPLACE FUNCTION update_all_vip_levels()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  -- Loop through all users who have transactions
  FOR v_user_record IN 
    SELECT DISTINCT user_id 
    FROM transactions
    WHERE created_at >= NOW() - INTERVAL '30 days'
  LOOP
    PERFORM update_user_vip_level(v_user_record.user_id);
  END LOOP;
END;
$$;

-- Trigger to update VIP level after transaction
CREATE OR REPLACE FUNCTION trigger_update_vip_after_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only update for trading transactions
  IF NEW.type IN ('open_position', 'close_position', 'swap') THEN
    PERFORM update_user_vip_level(NEW.user_id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS update_vip_after_transaction ON transactions;

-- Create trigger on transactions table
CREATE TRIGGER update_vip_after_transaction
  AFTER INSERT ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_vip_after_transaction();

-- Initialize VIP levels for all existing users
DO $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN 
    SELECT DISTINCT user_id 
    FROM transactions
  LOOP
    PERFORM update_user_vip_level(v_user_record.user_id);
  END LOOP;
END;
$$;
