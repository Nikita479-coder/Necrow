/*
  # Final Adjustment - Hit Exactly 7-8% Monthly

  1. Changes
    - Adjust multipliers to account for losing days
    - Winning days: slightly higher gains
    - Target: exactly 7-8% monthly with 70% win rate
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

  -- Calculate base daily ROI needed
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

  -- Calculate daily ROI
  -- With 70% win rate (21 wins, 9 losses):
  -- Target 7.5% monthly = (21 * win_pct) + (9 * loss_pct) = 7.5%
  -- If avg loss is -0.08%, then: (21 * win_pct) + (9 * -0.08) = 7.5
  -- So: 21 * win_pct = 7.5 + 0.72 = 8.22
  -- win_pct = 0.391% per winning day
  IF v_is_profitable THEN
    -- Profitable day: 0.35% to 0.43% gain (avg ~0.39%)
    v_daily_roi := (v_base_daily_roi * 1.56) * (0.90 + v_random_factor * 0.23);
  ELSE
    -- Losing day: -0.06% to -0.10% loss (avg ~0.08%)
    v_daily_roi := -(v_base_daily_roi * 0.32) * (0.75 + v_random_factor * 0.50);
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
  pnl_90d = 0, roi_90d = 0, profitable_days = 0, trading_days = 0
WHERE is_automated = true;
