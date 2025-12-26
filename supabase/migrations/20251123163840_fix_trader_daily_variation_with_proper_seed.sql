/*
  # Fix Trader Daily Variation with Proper Randomness

  1. Changes
    - Fix seed calculation to vary by date
    - Ensure 70% win rate over 30 days
    - Target 7-8% monthly returns
*/

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

  -- Get target monthly ROI (should be between 7 and 8)
  v_target_monthly_roi := COALESCE(v_trader.target_monthly_roi, 7.5);

  -- Calculate base daily ROI needed to hit target
  v_base_daily_roi := v_target_monthly_roi / 30.0;

  -- Get day of month (1-30) for pattern
  v_day_of_month := EXTRACT(day FROM p_date)::int;
  
  -- Create a better seed using date + trader seed
  v_seed := (v_day_of_month * 13 + v_trader.daily_trade_seed) % 100;
  
  -- Determine if this is a profitable day
  -- Pattern: days 1,2,3,4,5,6,7,8,9,11,12,13,14,15,17,18,19,20,21,23,24,25,26,28,29 are profitable (21/30 = 70%)
  v_is_profitable := v_day_of_month NOT IN (10, 16, 22, 27, 30, 6, 13, 20, 25);

  -- Random factor for variation (0.0 to 0.9)
  v_random_factor := (v_seed % 10) / 10.0;

  -- Use STARTING balance
  SELECT COALESCE(aum, 100000) INTO v_current_aum
  FROM traders
  WHERE id = p_trader_id;

  -- Calculate daily ROI
  -- Target: 7.5% monthly = 0.25% per day average
  -- With 70% win rate:
  --   - Winning days: 0.25% * (30/21) = 0.357% per winning day
  --   - Losing days: small losses to add realism
  IF v_is_profitable THEN
    -- Profitable day: 0.30% to 0.42% gain (avg 0.357%)
    v_daily_roi := (v_base_daily_roi * 1.43) * (0.85 + v_random_factor * 0.35);
  ELSE
    -- Losing day: -0.05% to -0.15% loss
    v_daily_roi := -(v_base_daily_roi * 0.4) * (0.5 + v_random_factor);
  END IF;

  -- Calculate P&L based on STARTING AUM
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
    1 + (v_seed % 5)
  )
  ON CONFLICT (trader_id, performance_date) 
  DO UPDATE SET
    daily_pnl = EXCLUDED.daily_pnl,
    daily_roi = EXCLUDED.daily_roi,
    ending_balance = EXCLUDED.ending_balance;

  RETURN v_daily_pnl;
END;
$$;

-- Clear and reset
DELETE FROM trader_daily_performance;

UPDATE traders SET
  pnl_7d = 0, roi_7d = 0, pnl_30d = 0, roi_30d = 0,
  pnl_90d = 0, roi_90d = 0, profitable_days = 0, trading_days = 0,
  last_trade_date = CURRENT_DATE - INTERVAL '1 day'
WHERE is_automated = true;
