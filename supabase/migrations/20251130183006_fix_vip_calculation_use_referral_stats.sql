/*
  # Fix VIP Calculation to Use Referral Stats

  1. Changes
    - Update calculate_user_vip_level to use referral_stats table
    - Integrate with existing volume tracking system
    - Sync VIP status with referral_stats

  2. Purpose
    - Fix relation not found error
    - Use correct table for volume tracking
*/

-- Calculate and update user's VIP level based on 30-day volume
CREATE OR REPLACE FUNCTION calculate_user_vip_level(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_volume_30d numeric;
  v_level_record RECORD;
BEGIN
  -- Calculate 30-day trading volume from referral_stats
  SELECT COALESCE(total_volume_30d, 0) INTO v_volume_30d
  FROM referral_stats
  WHERE user_id = p_user_id;

  -- If no volume record, calculate it fresh
  IF v_volume_30d IS NULL THEN
    v_volume_30d := calculate_user_30d_volume(p_user_id);
  END IF;

  -- Find matching VIP level
  SELECT * INTO v_level_record
  FROM vip_levels
  WHERE v_volume_30d >= min_volume_30d
    AND (max_volume_30d IS NULL OR v_volume_30d <= max_volume_30d)
  ORDER BY level_number DESC
  LIMIT 1;

  -- If no level found, default to VIP 1
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
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    current_level = EXCLUDED.current_level,
    volume_30d = EXCLUDED.volume_30d,
    commission_rate = EXCLUDED.commission_rate,
    rebate_rate = EXCLUDED.rebate_rate,
    last_calculated_at = EXCLUDED.last_calculated_at,
    updated_at = now();

  -- Also update referral_stats to keep vip_level in sync
  UPDATE referral_stats
  SET vip_level = v_level_record.level_number
  WHERE user_id = p_user_id;
END;
$$;

-- Update all users' VIP levels (for scheduled jobs)
CREATE OR REPLACE FUNCTION update_all_user_vip_levels()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN
    SELECT DISTINCT id FROM auth.users
  LOOP
    PERFORM calculate_user_vip_level(v_user_record.id);
  END LOOP;
END;
$$;