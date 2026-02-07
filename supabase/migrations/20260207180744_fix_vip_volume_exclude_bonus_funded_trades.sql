/*
  # Fix VIP Volume Calculation to Exclude Bonus-Funded Trades

  1. Problem
    - Users can inflate their VIP level by trading with locked bonus funds
    - The current volume calculation includes ALL positions regardless of fund source
    - This undermines the VIP tier system which should only reward real trading volume

  2. Solution
    - Update `update_30day_volumes()` to calculate volume proportionally based on margin source
    - Update `update_user_volume_on_position()` trigger to only count real wallet margin
    - Update `update_user_volume_on_swap()` trigger (swap orders use real funds, no change needed)
    
  3. Calculation Logic
    - For each position: volume_contribution = notional_value * (1 - bonus_margin / total_margin)
    - Positions funded 100% by bonus = 0 volume contribution
    - Positions funded 50% by bonus = 50% volume contribution
    - Positions funded 100% by real wallet = 100% volume contribution

  4. Impact
    - VIP levels will now accurately reflect real trading activity
    - Users cannot game the VIP system with bonus-funded trades
    - Fix only applies to future calculations (existing data unchanged)
*/

-- Update the main volume calculation function
CREATE OR REPLACE FUNCTION update_30day_volumes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record record;
  v_volume_30d numeric;
BEGIN
  FOR v_user_record IN 
    SELECT DISTINCT id as user_id FROM user_profiles
  LOOP
    WITH futures_volume AS (
      SELECT COALESCE(SUM(
        quantity * entry_price * (
          1.0 - COALESCE(margin_from_locked_bonus, 0) / NULLIF(margin_amount, 0)
        )
      ), 0) as volume
      FROM futures_positions
      WHERE user_id = v_user_record.user_id
        AND opened_at >= now() - INTERVAL '30 days'
        AND margin_amount > 0
    ),
    swap_volume AS (
      SELECT COALESCE(SUM(
        CASE 
          WHEN from_currency = 'USDT' THEN from_amount
          WHEN to_currency = 'USDT' THEN to_amount
          ELSE from_amount * 40000
        END
      ), 0) as volume
      FROM swap_orders
      WHERE user_id = v_user_record.user_id
        AND status = 'executed'
        AND created_at >= now() - INTERVAL '30 days'
    )
    SELECT 
      COALESCE(f.volume, 0) + COALESCE(s.volume, 0)
    INTO v_volume_30d
    FROM futures_volume f, swap_volume s;
    
    INSERT INTO referral_stats (
      user_id,
      total_volume_30d,
      total_volume_all_time,
      this_month_earnings,
      total_earnings,
      total_referrals,
      vip_level
    ) VALUES (
      v_user_record.user_id,
      v_volume_30d,
      0,
      0,
      0,
      0,
      1
    )
    ON CONFLICT (user_id) DO UPDATE SET
      total_volume_30d = EXCLUDED.total_volume_30d,
      updated_at = now()
    WHERE referral_stats.total_volume_30d != EXCLUDED.total_volume_30d;
    
    PERFORM calculate_user_vip_level(v_user_record.user_id);
  END LOOP;
  
  RAISE NOTICE '30-day volumes updated for all users (excluding bonus-funded trades)';
END;
$$;

-- Update trigger function to only count real wallet volume
CREATE OR REPLACE FUNCTION update_user_volume_on_position()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_real_margin_ratio numeric;
  v_notional_value numeric;
  v_real_volume numeric;
BEGIN
  IF NEW.margin_amount IS NULL OR NEW.margin_amount <= 0 THEN
    RETURN NEW;
  END IF;
  
  v_real_margin_ratio := 1.0 - COALESCE(NEW.margin_from_locked_bonus, 0) / NEW.margin_amount;
  
  IF v_real_margin_ratio <= 0 THEN
    RETURN NEW;
  END IF;
  
  v_notional_value := NEW.quantity * NEW.entry_price;
  v_real_volume := v_notional_value * v_real_margin_ratio;
  
  INSERT INTO referral_stats (
    user_id,
    total_volume_30d,
    total_volume_all_time,
    this_month_earnings,
    total_earnings,
    total_referrals,
    vip_level
  ) VALUES (
    NEW.user_id,
    v_real_volume,
    0,
    0,
    0,
    0,
    1
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_volume_30d = referral_stats.total_volume_30d + v_real_volume,
    updated_at = now();
  
  RETURN NEW;
END;
$$;