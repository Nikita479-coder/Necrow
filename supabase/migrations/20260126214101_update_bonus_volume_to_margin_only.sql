/*
  # Update Bonus Volume Tracking to Use Margin Only

  1. Changes
    - Updates `calculate_volume_contribution` function to use margin amount 
      instead of notional value (margin x leverage)
    - Bonus volume for unlock requirements now based on margin used, not position size
    - This makes volume requirements 500x based on actual margin, not leveraged position

  2. Important Notes
    - Volume for bonuses = margin used (not position size)
    - Real trading volume for VIP/referrals still uses notional value
    - 500x multiplier means for $20 bonus, user needs $10,000 in margin trades
*/

-- Drop the old function first
DROP FUNCTION IF EXISTS calculate_volume_contribution(numeric, numeric, numeric, numeric, timestamptz, timestamptz, integer);

-- Recreate with updated logic: bonus volume = margin only
CREATE OR REPLACE FUNCTION calculate_volume_contribution(
  p_position_size numeric,
  p_entry_price numeric,
  p_margin_amount numeric,
  p_margin_from_locked_bonus numeric,
  p_opened_at timestamptz,
  p_closed_at timestamptz,
  p_minimum_duration_minutes integer
)
RETURNS TABLE(
  bonus_volume numeric,
  real_volume numeric,
  total_notional numeric,
  bonus_percentage numeric,
  real_percentage numeric,
  duration_met boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notional_value numeric;
  v_bonus_percentage numeric;
  v_real_percentage numeric;
  v_duration_met boolean;
  v_bonus_vol numeric;
  v_real_vol numeric;
  v_bonus_margin numeric;
  v_real_margin numeric;
BEGIN
  -- Calculate total notional value (for reference/VIP tracking)
  v_notional_value := ABS(p_position_size * p_entry_price);
  
  -- Check if position meets duration requirement
  v_duration_met := position_meets_duration_requirement(
    p_opened_at,
    p_closed_at,
    p_minimum_duration_minutes
  );
  
  -- Calculate what percentage of margin came from each source
  IF p_margin_amount > 0 THEN
    v_bonus_percentage := LEAST(1.0, COALESCE(p_margin_from_locked_bonus, 0) / p_margin_amount);
    v_real_percentage := 1.0 - v_bonus_percentage;
  ELSE
    v_bonus_percentage := 0;
    v_real_percentage := 1.0;
  END IF;
  
  -- Calculate margin amounts from each source
  v_bonus_margin := p_margin_amount * v_bonus_percentage;
  v_real_margin := p_margin_amount * v_real_percentage;
  
  -- BONUS VOLUME: Use MARGIN only (not notional value / leveraged position)
  -- This means volume requirement is based on actual margin used, not margin x leverage
  IF v_duration_met AND v_bonus_percentage > 0 THEN
    v_bonus_vol := v_bonus_margin;  -- Margin only, NOT notional
  ELSE
    v_bonus_vol := 0;
  END IF;
  
  -- REAL VOLUME for VIP/referrals: Still use notional value
  IF v_real_percentage > 0 THEN
    v_real_vol := v_notional_value * v_real_percentage;
  ELSE
    v_real_vol := 0;
  END IF;
  
  -- Return the calculated values
  RETURN QUERY SELECT
    v_bonus_vol,
    v_real_vol,
    v_notional_value,
    v_bonus_percentage * 100,
    v_real_percentage * 100,
    v_duration_met;
END;
$$;

-- Add comment explaining the volume calculation
COMMENT ON FUNCTION calculate_volume_contribution IS 
'Calculates volume contribution for bonus unlock and VIP tracking.
BONUS volume = margin used only (NOT leveraged position size)
REAL volume = notional value (for VIP/referral tracking)
500x bonus requirement means: $20 bonus requires $10,000 in margin-based futures trades';
