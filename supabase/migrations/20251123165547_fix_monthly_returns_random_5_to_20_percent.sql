/*
  # Fix Monthly Returns to be Random -5% to +20%

  1. Changes
    - Target monthly returns: -5% to +20% (each trader gets a random target)
    - Daily returns calculated to hit monthly target
    - 70% profitable days, 30% losing days for realism
    - Monthly ROI will vary between -5% and +20%
*/

-- Update all traders to have random monthly targets between -5% and +20%
UPDATE traders 
SET target_monthly_roi = -5.0 + (random() * 25.0)
WHERE is_automated = true;

-- Recreate function to hit monthly targets with daily variation
CREATE OR REPLACE FUNCTION generate_daily_trader_pnl(
  p_trader_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_daily_roi numeric;
  v_daily_pnl numeric;
  v_current_aum numeric;
  v_seed int;
  v_day_of_month int;
  v_is_profitable boolean;
  v_random_factor numeric;
  v_target_monthly_roi numeric;
  v_base_daily_roi numeric;
BEGIN
  -- Get trader info
  SELECT * INTO v_trader
  FROM traders
  WHERE id = p_trader_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trader not found';
  END IF;

  -- Don't process if not automated
  IF NOT v_trader.is_automated THEN
    RETURN 0;
  END IF;

  -- Get target monthly ROI (between -5 and +20)
  v_target_monthly_roi := COALESCE(v_trader.target_monthly_roi, 7.5);

  -- Calculate base daily ROI needed to hit monthly target
  v_base_daily_roi := v_target_monthly_roi / 30.0;

  -- Get day of month for pattern
  v_day_of_month := EXTRACT(day FROM p_date)::int;
  
  -- Create seed
  v_seed := (v_day_of_month * 13 + v_trader.daily_trade_seed) % 100;
  
  -- 21 profitable days out of 30 (70% win rate)
  v_is_profitable := v_day_of_month NOT IN (10, 16, 22, 27, 30, 6, 13, 20, 25);

  -- Random factor
  v_random_factor := (v_seed % 10) / 10.0;

  -- Use STARTING balance
  SELECT COALESCE(aum, 100000) INTO v_current_aum
  FROM traders
  WHERE id = p_trader_id;

  -- Calculate daily ROI to hit monthly target
  -- Math: 70% winning days need to offset 30% losing days and hit target
  -- If target is X% monthly:
  -- (21 * win_avg) + (9 * loss_avg) = X%
  -- Assuming loss_avg = -0.08% of base:
  -- 21 * win_avg = X + (9 * 0.08 * X/30)
  -- win_avg = (X + 0.024X) / 21 = X * 1.024 / 21 ≈ X * 0.0488
  -- So win_avg = base_daily * 1.46
  
  IF v_is_profitable THEN
    -- Profitable day: scaled to hit monthly target
    v_daily_roi := (v_base_daily_roi * 1.46) * (0.85 + v_random_factor * 0.30);
  ELSE
    -- Losing day: small loss relative to base
    v_daily_roi := -(ABS(v_base_daily_roi) * 0.30) * (0.50 + v_random_factor * 0.50);
  END IF;

  -- Calculate P&L
  v_daily_pnl := v_current_aum * (v_daily_roi / 100);

  -- Insert daily performance record
  INSERT INTO trader_daily_performance (
    trader_id,
    performance_date,
    daily_pnl,
    daily_roi,
    starting_balance,
    ending_balance,
    trades_count
  ) VALUES (
    p_trader_id,
    p_date,
    v_daily_pnl,
    v_daily_roi,
    v_current_aum,
    v_current_aum + v_daily_pnl,
    1 + ((v_seed % 3) + 1)
  )
  ON CONFLICT (trader_id, performance_date) 
  DO UPDATE SET
    daily_pnl = EXCLUDED.daily_pnl,
    daily_roi = EXCLUDED.daily_roi,
    ending_balance = EXCLUDED.ending_balance;

  RETURN v_daily_pnl;
END;
$$;

-- Clear existing performance data
DELETE FROM trader_daily_performance;

-- Reset trader stats
UPDATE traders SET
  pnl_7d = 0, roi_7d = 0, pnl_30d = 0, roi_30d = 0,
  pnl_90d = 0, roi_90d = 0, profitable_days = 0, trading_days = 0,
  last_trade_date = CURRENT_DATE - INTERVAL '1 day'
WHERE is_automated = true;
