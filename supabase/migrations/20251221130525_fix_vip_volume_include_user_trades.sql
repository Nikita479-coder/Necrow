/*
  # Fix VIP Volume Tracking to Include User's Own Trades

  1. Changes
    - Update `update_30day_volumes()` function to calculate volume from user's own trades
    - Include all futures positions opened in the last 30 days
    - Calculate based on notional value (quantity * entry_price)
    - Also include swap trading volume

  2. Impact
    - Users will now see their VIP level update immediately based on their own trading
    - 30-day volume will accurately reflect both futures and swap trading activity
    - VIP levels will be calculated correctly for all users

  3. Security
    - Maintains SECURITY DEFINER for consistent execution
    - Uses proper search_path
*/

-- Fix the update_30day_volumes function to include user's own trading volume
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
  -- For each user
  FOR v_user_record IN 
    SELECT DISTINCT id as user_id FROM user_profiles
  LOOP
    -- Calculate 30-day volume from:
    -- 1. User's own futures positions (notional value)
    -- 2. User's own swap trades (from_amount in USDT equivalent)
    
    WITH futures_volume AS (
      SELECT COALESCE(SUM(quantity * entry_price), 0) as volume
      FROM futures_positions
      WHERE user_id = v_user_record.user_id
        AND opened_at >= now() - INTERVAL '30 days'
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
    
    -- Update or insert referral_stats with the calculated volume
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
    
    -- Calculate and update VIP level for this user
    PERFORM calculate_user_vip_level(v_user_record.user_id);
  END LOOP;
  
  RAISE NOTICE '30-day volumes updated for all users';
END;
$$;

-- Create a trigger function to update volume immediately when a position is opened
CREATE OR REPLACE FUNCTION update_user_volume_on_position()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notional_value numeric;
BEGIN
  -- Calculate notional value of this position
  v_notional_value := NEW.quantity * NEW.entry_price;
  
  -- Update referral_stats volume immediately
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
    v_notional_value,
    0,
    0,
    0,
    0,
    1
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_volume_30d = referral_stats.total_volume_30d + v_notional_value,
    updated_at = now();
  
  RETURN NEW;
END;
$$;

-- Create trigger to update volume on new position
DROP TRIGGER IF EXISTS update_volume_on_position_insert ON futures_positions;

CREATE TRIGGER update_volume_on_position_insert
  AFTER INSERT ON futures_positions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_volume_on_position();

-- Create similar trigger for swap orders
CREATE OR REPLACE FUNCTION update_user_volume_on_swap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_volume_usdt numeric;
BEGIN
  -- Only process executed swaps
  IF NEW.status != 'executed' THEN
    RETURN NEW;
  END IF;
  
  -- Calculate volume in USDT equivalent
  IF NEW.from_currency = 'USDT' THEN
    v_volume_usdt := NEW.from_amount;
  ELSIF NEW.to_currency = 'USDT' THEN
    v_volume_usdt := NEW.to_amount;
  ELSE
    v_volume_usdt := NEW.from_amount * 40000;
  END IF;
  
  -- Update referral_stats volume immediately
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
    v_volume_usdt,
    0,
    0,
    0,
    0,
    1
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_volume_30d = referral_stats.total_volume_30d + v_volume_usdt,
    updated_at = now();
  
  RETURN NEW;
END;
$$;

-- Create trigger to update volume on executed swap
DROP TRIGGER IF EXISTS update_volume_on_swap_execute ON swap_orders;

CREATE TRIGGER update_volume_on_swap_execute
  AFTER INSERT OR UPDATE ON swap_orders
  FOR EACH ROW
  WHEN (NEW.status = 'executed')
  EXECUTE FUNCTION update_user_volume_on_swap();

-- Recalculate all volumes immediately
SELECT update_30day_volumes();
