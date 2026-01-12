/*
  # VIP Level Calculation and Fee Rebate Functions

  1. New Functions
    - `calculate_user_vip_level` - Calculate user's VIP level based on 30-day volume
    - `apply_fee_rebate` - Apply fee rebate to user's wallet based on VIP level
    - `update_all_user_vip_levels` - Batch update all users' VIP levels

  2. Purpose
    - Automatically calculate VIP tiers from trading volume
    - Apply fee rebates to reduce effective trading costs
    - Keep VIP status up to date
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
  -- Calculate 30-day trading volume from user_volume_tracking
  SELECT COALESCE(volume_30d, 0) INTO v_volume_30d
  FROM user_volume_tracking
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
END;
$$;

-- Apply fee rebate to user's wallet based on their VIP level
CREATE OR REPLACE FUNCTION apply_fee_rebate(
  p_user_id uuid,
  p_fee_amount numeric,
  p_fee_type text,
  p_related_entity_id text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rebate_rate numeric;
  v_rebate_amount numeric;
  v_wallet_id uuid;
BEGIN
  -- Get user's rebate rate
  SELECT rebate_rate INTO v_rebate_rate
  FROM user_vip_status
  WHERE user_id = p_user_id;

  -- If no VIP status found, use VIP 1 default (5%)
  IF v_rebate_rate IS NULL THEN
    v_rebate_rate := 5;
  END IF;

  -- Calculate rebate amount
  v_rebate_amount := p_fee_amount * (v_rebate_rate / 100);

  -- Get or create user's spot wallet for USDT
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, 'USDT', 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO NOTHING
  RETURNING wallet_id INTO v_wallet_id;

  IF v_wallet_id IS NULL THEN
    SELECT wallet_id INTO v_wallet_id
    FROM wallets
    WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'spot';
  END IF;

  -- Credit rebate to user's wallet
  UPDATE wallets
  SET balance = balance + v_rebate_amount,
      updated_at = now()
  WHERE wallet_id = v_wallet_id;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    p_user_id,
    'fee_rebate',
    v_rebate_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'original_fee', p_fee_amount,
      'rebate_rate', v_rebate_rate,
      'fee_type', p_fee_type,
      'related_entity_id', p_related_entity_id
    )
  );

  RETURN v_rebate_amount;
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
    SELECT DISTINCT user_id FROM user_volume_tracking
  LOOP
    PERFORM calculate_user_vip_level(v_user_record.user_id);
  END LOOP;
END;
$$;