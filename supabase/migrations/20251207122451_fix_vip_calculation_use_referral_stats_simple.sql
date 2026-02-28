/*
  # Fix VIP Level Calculation to Use Correct Volume Source

  1. Changes
    - Update calculate_user_vip_level to read volume from referral_stats.total_volume_30d
    - Add vip_downgrade to allowed notification types
    - Fix track_vip_level_change trigger to use 'read' column
    - Recalculate all users' VIP levels using correct volume data

  2. Impact
    - Users with 4.1M volume will correctly be assigned VIP 1 (not VIP 2)
    - VIP tiers will accurately reflect 30-day trading volume
*/

-- Add vip_downgrade to allowed notification types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout'::text, 
    'trade_executed'::text, 
    'kyc_update'::text, 
    'account_update'::text, 
    'system'::text, 
    'position_closed'::text, 
    'position_tp_hit'::text, 
    'position_sl_hit'::text, 
    'pending_trade'::text, 
    'trade_accepted'::text, 
    'trade_rejected'::text, 
    'shark_card_application'::text, 
    'shark_card_approved'::text, 
    'shark_card_declined'::text, 
    'shark_card_issued'::text,
    'vip_downgrade'::text,
    'vip_refill'::text
  ])
);

-- Fix the trigger function to use correct column name
CREATE OR REPLACE FUNCTION track_vip_level_change()
RETURNS TRIGGER AS $$
DECLARE
  v_previous_level integer;
  v_change_type text;
  v_volume_30d numeric;
BEGIN
  -- Get previous level
  v_previous_level := OLD.current_level;
  
  -- Determine change type
  IF NEW.current_level > OLD.current_level THEN
    v_change_type := 'upgrade';
  ELSIF NEW.current_level < OLD.current_level THEN
    v_change_type := 'downgrade';
  ELSE
    v_change_type := 'maintained';
  END IF;

  -- Get current 30-day volume
  v_volume_30d := COALESCE(NEW.volume_30d, 0);

  -- Insert into history
  INSERT INTO vip_level_history (
    user_id,
    previous_level,
    new_level,
    previous_tier_name,
    new_tier_name,
    change_type,
    volume_30d
  ) VALUES (
    NEW.user_id,
    v_previous_level,
    NEW.current_level,
    get_vip_tier_name(v_previous_level),
    get_vip_tier_name(NEW.current_level),
    v_change_type,
    v_volume_30d
  );

  -- If it's a downgrade, create a downgrade record
  IF v_change_type = 'downgrade' THEN
    INSERT INTO vip_tier_downgrades (
      user_id,
      previous_level,
      new_level,
      previous_tier_name,
      new_tier_name,
      tier_difference,
      volume_30d,
      status
    ) VALUES (
      NEW.user_id,
      v_previous_level,
      NEW.current_level,
      get_vip_tier_name(v_previous_level),
      get_vip_tier_name(NEW.current_level),
      v_previous_level - NEW.current_level,
      v_volume_30d,
      'pending'
    );

    -- Create notification for user (use 'read' column name not 'is_read')
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      read
    ) VALUES (
      NEW.user_id,
      'vip_downgrade',
      'VIP Tier Change',
      'Your VIP level has changed from ' || get_vip_tier_name(v_previous_level) || ' to ' || get_vip_tier_name(NEW.current_level) || '. Contact support for exclusive retention offers!',
      false
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Update VIP calculation function to use referral_stats table
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

  -- If no volume record, default to 0
  IF v_volume_30d IS NULL THEN
    v_volume_30d := 0;
  END IF;

  -- Find matching VIP level
  SELECT * INTO v_level_record
  FROM vip_levels
  WHERE v_volume_30d >= min_volume_30d
    AND (max_volume_30d IS NULL OR v_volume_30d <= max_volume_30d)
  ORDER BY level_number DESC
  LIMIT 1;

  -- If no level found, default to level 1
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
END;
$$;

-- Recalculate VIP levels for all users with trading volume
DO $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN
    SELECT user_id FROM referral_stats WHERE total_volume_30d > 0
  LOOP
    PERFORM calculate_user_vip_level(v_user_record.user_id);
  END LOOP;
END $$;