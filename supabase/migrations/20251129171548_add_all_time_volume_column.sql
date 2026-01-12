/*
  # Add All-Time Volume Column to Referral Stats

  1. Changes
    - Add total_volume_all_time column to referral_stats table
    - Update function to work with current schema
*/

-- Add all-time volume column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'referral_stats' AND column_name = 'total_volume_all_time'
  ) THEN
    ALTER TABLE referral_stats ADD COLUMN total_volume_all_time numeric(20, 8) DEFAULT 0 NOT NULL;
  END IF;
END $$;

-- Update function to properly handle the schema
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
    total_referrals,
    total_earnings,
    updated_at
  )
  VALUES (
    p_user_id,
    v_new_vip_level,
    v_volume,
    v_all_time_volume,
    0,
    0,
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