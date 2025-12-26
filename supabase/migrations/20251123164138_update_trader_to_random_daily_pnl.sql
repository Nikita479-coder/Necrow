/*
  # Update Trader Performance to Random Daily P&L

  1. Changes
    - Daily returns now range from -5% to +20%
    - More volatility and unpredictability
    - Each day is completely random within the range
    - No longer targeting specific monthly returns
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
  v_random_value numeric;
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

  -- Create seed based on date and trader
  v_seed := (EXTRACT(epoch FROM p_date)::int + v_trader.daily_trade_seed) % 10000;
  
  -- Generate random value between 0 and 1
  v_random_value := (v_seed::numeric / 10000.0);
  
  -- Map to range -5% to +20% (25% total range)
  -- Random value 0.0 = -5%, random value 1.0 = +20%
  v_daily_roi := -5.0 + (v_random_value * 25.0);

  -- Use current AUM
  SELECT COALESCE(aum, 100000) INTO v_current_aum
  FROM traders
  WHERE id = p_trader_id;

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

-- Update the statistics function to handle the new volatile returns
CREATE OR REPLACE FUNCTION update_trader_statistics(p_trader_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_stats RECORD;
  v_7d_stats RECORD;
  v_30d_stats RECORD;
  v_90d_stats RECORD;
BEGIN
  -- Get current trader
  SELECT * INTO v_trader FROM traders WHERE id = p_trader_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Calculate 7-day stats
  SELECT 
    COALESCE(SUM(daily_pnl), 0) as total_pnl,
    COALESCE(SUM(daily_roi), 0) as total_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_7d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '6 days';

  -- Calculate 30-day stats
  SELECT 
    COALESCE(SUM(daily_pnl), 0) as total_pnl,
    COALESCE(SUM(daily_roi), 0) as total_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_30d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '29 days';

  -- Calculate 90-day stats
  SELECT 
    COALESCE(SUM(daily_pnl), 0) as total_pnl,
    COALESCE(SUM(daily_roi), 0) as total_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_90d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '89 days';

  -- Update trader with calculated stats
  UPDATE traders SET
    -- 7-day metrics
    pnl_7d = v_7d_stats.total_pnl,
    roi_7d = v_7d_stats.total_roi,
    avg_win_rate_7d = CASE 
      WHEN v_7d_stats.total_days > 0 
      THEN (v_7d_stats.profitable_days::numeric / v_7d_stats.total_days * 100)
      ELSE 50
    END,

    -- 30-day metrics
    pnl_30d = v_30d_stats.total_pnl,
    roi_30d = v_30d_stats.total_roi,
    monthly_return = v_30d_stats.total_roi,

    -- 90-day metrics
    pnl_90d = v_90d_stats.total_pnl,
    roi_90d = v_90d_stats.total_roi,
    avg_win_rate_90d = CASE 
      WHEN v_90d_stats.total_days > 0 
      THEN (v_90d_stats.profitable_days::numeric / v_90d_stats.total_days * 100)
      ELSE 50
    END,

    -- Update AUM based on performance
    aum = GREATEST(v_trader.aum + v_30d_stats.total_pnl, 10000),

    -- Update trading days
    trading_days = v_90d_stats.total_days,
    profitable_days = v_90d_stats.profitable_days,

    -- Update win rate
    win_rate = CASE 
      WHEN v_30d_stats.total_days > 0 
      THEN (v_30d_stats.profitable_days::numeric / v_30d_stats.total_days * 100)
      ELSE 50
    END,

    last_trade_date = CURRENT_DATE,
    updated_at = NOW()

  WHERE id = p_trader_id;
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

-- Set random seeds for more variation
UPDATE traders SET daily_trade_seed = (random() * 9999)::int WHERE is_automated = true;
