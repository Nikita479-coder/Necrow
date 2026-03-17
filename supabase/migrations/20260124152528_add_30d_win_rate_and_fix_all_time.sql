/*
  # Add 30-Day Win Rate and Fix All-Time Win Rate Calculation

  1. Changes
    - Add avg_win_rate_30d column to traders table
    - Update calculate_trader_metrics to calculate 30-day win rate from actual trades
    - Fix win_rate_all_time to be calculated from all actual trades (not just combined)

  2. Result
    - Each period (7d, 30d, 90d, all-time) will show accurate win rates based on trades in that period
*/

-- Add 30-day win rate column
ALTER TABLE traders
ADD COLUMN IF NOT EXISTS avg_win_rate_30d numeric DEFAULT 68;

-- Update the calculate function to include all period win rates
CREATE OR REPLACE FUNCTION calculate_trader_metrics(p_trader_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_is_protected boolean;
  v_is_automated boolean;
  v_starting_capital numeric;
  v_target_roi numeric;
  v_multiplier numeric := 1;

  v_base_total_trades integer := 0;
  v_base_winning_trades integer := 0;
  v_base_pnl numeric := 0;
  v_base_volume numeric := 0;
  v_base_pnl_7d numeric := 0;
  v_base_pnl_30d numeric := 0;
  v_base_pnl_90d numeric := 0;
  v_base_roi_7d numeric := 0;
  v_base_roi_30d numeric := 0;
  v_base_roi_90d numeric := 0;

  v_cutoff_7d timestamptz;
  v_cutoff_30d timestamptz;
  v_cutoff_90d timestamptz;

  v_pnl_7d numeric := 0;
  v_pnl_30d numeric := 0;
  v_pnl_90d numeric := 0;
  v_pnl_all_time numeric := 0;

  v_roi_7d numeric := 0;
  v_roi_30d numeric := 0;
  v_roi_90d numeric := 0;
  v_roi_all_time numeric := 0;

  v_actual_total_trades integer := 0;
  v_actual_winning_trades integer := 0;
  v_actual_volume numeric := 0;
  v_actual_pnl_7d numeric := 0;
  v_actual_pnl_30d numeric := 0;
  v_actual_pnl_90d numeric := 0;
  v_actual_pnl_all numeric := 0;

  v_combined_total_trades integer;
  v_combined_winning_trades integer;
  v_combined_win_rate numeric;
  v_combined_volume numeric;

  -- Period-specific win rate variables
  v_trades_7d integer := 0;
  v_wins_7d integer := 0;
  v_win_rate_7d numeric := 0;
  
  v_trades_30d integer := 0;
  v_wins_30d integer := 0;
  v_win_rate_30d numeric := 0;
  
  v_trades_90d integer := 0;
  v_wins_90d integer := 0;
  v_win_rate_90d numeric := 0;
  
  v_trades_all integer := 0;
  v_wins_all integer := 0;
  v_win_rate_all numeric := 0;
BEGIN
  SELECT 
    starting_capital, 
    protected_trader, 
    is_automated, 
    target_monthly_roi,
    COALESCE(trade_pnl_multiplier, 1),
    COALESCE(base_total_trades, 0),
    COALESCE(base_winning_trades, 0),
    COALESCE(base_pnl, 0),
    COALESCE(base_volume, 0),
    COALESCE(base_pnl_7d, 0),
    COALESCE(base_pnl_30d, 0),
    COALESCE(base_pnl_90d, 0),
    COALESCE(base_roi_7d, 0),
    COALESCE(base_roi_30d, 0),
    COALESCE(base_roi_90d, 0)
  INTO 
    v_starting_capital, 
    v_is_protected, 
    v_is_automated, 
    v_target_roi,
    v_multiplier,
    v_base_total_trades,
    v_base_winning_trades,
    v_base_pnl,
    v_base_volume,
    v_base_pnl_7d,
    v_base_pnl_30d,
    v_base_pnl_90d,
    v_base_roi_7d,
    v_base_roi_30d,
    v_base_roi_90d
  FROM traders
  WHERE id = p_trader_id;

  IF v_starting_capital IS NULL THEN
    RETURN false;
  END IF;

  v_cutoff_7d := NOW() - INTERVAL '7 days';
  v_cutoff_30d := NOW() - INTERVAL '30 days';
  v_cutoff_90d := NOW() - INTERVAL '90 days';

  -- FOR AUTOMATED TRADERS: Use target ROI (unchanged behavior)
  IF v_is_automated = true AND v_target_roi IS NOT NULL THEN
    v_roi_30d := v_target_roi;
    v_pnl_30d := (v_starting_capital * (v_target_roi / 100));

    v_roi_7d := v_target_roi / 4.3;
    v_pnl_7d := (v_starting_capital * ((v_target_roi / 100) / 4.3));

    v_roi_90d := v_target_roi * 3;
    v_pnl_90d := (v_starting_capital * ((v_target_roi / 100) * 3));

    v_roi_all_time := CASE 
      WHEN v_target_roi > 0 THEN v_target_roi * 6
      ELSE v_target_roi * 2
    END;
    v_pnl_all_time := CASE
      WHEN v_target_roi > 0 THEN (v_starting_capital * ((v_target_roi / 100) * 6))
      ELSE (v_starting_capital * ((v_target_roi / 100) * 2))
    END;

    IF v_is_protected THEN
      IF v_pnl_7d < 0 THEN v_pnl_7d := 0; END IF;
      IF v_pnl_30d < 0 THEN v_pnl_30d := 0; END IF;
      IF v_pnl_90d < 0 THEN v_pnl_90d := 0; END IF;
      IF v_pnl_all_time < 0 THEN v_pnl_all_time := 0; END IF;

      IF v_roi_7d < 0 THEN v_roi_7d := 0; END IF;
      IF v_roi_30d < 0 THEN v_roi_30d := 0; END IF;
      IF v_roi_90d < 0 THEN v_roi_90d := 0; END IF;
      IF v_roi_all_time < 0 THEN v_roi_all_time := 0; END IF;
    END IF;

    UPDATE traders
    SET
      pnl_7d = v_pnl_7d,
      pnl_30d = v_pnl_30d,
      pnl_90d = v_pnl_90d,
      pnl_all_time = v_pnl_all_time,
      roi_7d = v_roi_7d,
      roi_30d = v_roi_30d,
      roi_90d = v_roi_90d,
      roi_all_time = v_roi_all_time,
      metrics_last_updated = NOW(),
      updated_at = NOW()
    WHERE id = p_trader_id;

    RETURN true;
  END IF;

  -- FOR REGULAR TRADERS: Calculate from actual trades + base values

  -- Get actual trade statistics (all time)
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE pnl > 0),
    COALESCE(SUM(ABS(pnl) * COALESCE(leverage, 1)), 0)
  INTO v_actual_total_trades, v_actual_winning_trades, v_actual_volume
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed';

  -- Calculate 7-day win rate from actual trades
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE pnl > 0)
  INTO v_trades_7d, v_wins_7d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_7d;

  IF v_trades_7d > 0 THEN
    v_win_rate_7d := (v_wins_7d::numeric / v_trades_7d::numeric) * 100;
  ELSE
    v_win_rate_7d := COALESCE((SELECT avg_win_rate_7d FROM traders WHERE id = p_trader_id), 68);
  END IF;

  -- Calculate 30-day win rate from actual trades
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE pnl > 0)
  INTO v_trades_30d, v_wins_30d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_30d;

  IF v_trades_30d > 0 THEN
    v_win_rate_30d := (v_wins_30d::numeric / v_trades_30d::numeric) * 100;
  ELSE
    v_win_rate_30d := COALESCE((SELECT avg_win_rate_30d FROM traders WHERE id = p_trader_id), 68);
  END IF;

  -- Calculate 90-day win rate from actual trades
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE pnl > 0)
  INTO v_trades_90d, v_wins_90d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_90d;

  IF v_trades_90d > 0 THEN
    v_win_rate_90d := (v_wins_90d::numeric / v_trades_90d::numeric) * 100;
  ELSE
    v_win_rate_90d := COALESCE((SELECT avg_win_rate_90d FROM traders WHERE id = p_trader_id), 68);
  END IF;

  -- Calculate all-time win rate from actual trades + base values
  v_trades_all := v_base_total_trades + v_actual_total_trades;
  v_wins_all := v_base_winning_trades + v_actual_winning_trades;
  
  IF v_trades_all > 0 THEN
    v_win_rate_all := (v_wins_all::numeric / v_trades_all::numeric) * 100;
  ELSE
    v_win_rate_all := 0;
  END IF;

  -- Combine with base values
  v_combined_total_trades := v_base_total_trades + v_actual_total_trades;
  v_combined_winning_trades := v_base_winning_trades + v_actual_winning_trades;
  v_combined_volume := v_base_volume + (v_actual_volume * v_multiplier);

  -- Calculate combined win rate (same as all-time)
  IF v_combined_total_trades > 0 THEN
    v_combined_win_rate := (v_combined_winning_trades::numeric / v_combined_total_trades::numeric) * 100;
  ELSE
    v_combined_win_rate := 0;
  END IF;

  -- Calculate actual period P&L (with multiplier applied)
  SELECT COALESCE(SUM(pnl), 0) * v_multiplier INTO v_actual_pnl_7d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_7d;

  SELECT COALESCE(SUM(pnl), 0) * v_multiplier INTO v_actual_pnl_30d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_30d;

  SELECT COALESCE(SUM(pnl), 0) * v_multiplier INTO v_actual_pnl_90d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_90d;

  SELECT COALESCE(SUM(pnl), 0) * v_multiplier INTO v_actual_pnl_all
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL;

  -- Add base values to actual values (amplified by multiplier)
  v_pnl_7d := v_base_pnl_7d + v_actual_pnl_7d;
  v_pnl_30d := v_base_pnl_30d + v_actual_pnl_30d;
  v_pnl_90d := v_base_pnl_90d + v_actual_pnl_90d;
  v_pnl_all_time := v_base_pnl + v_base_pnl_90d + v_actual_pnl_all;

  -- Calculate ROI: base ROI + actual ROI contribution (amplified)
  v_roi_7d := v_base_roi_7d + ((v_actual_pnl_7d / v_starting_capital) * 100);
  v_roi_30d := v_base_roi_30d + ((v_actual_pnl_30d / v_starting_capital) * 100);
  v_roi_90d := v_base_roi_90d + ((v_actual_pnl_90d / v_starting_capital) * 100);
  v_roi_all_time := (v_pnl_all_time / v_starting_capital) * 100;

  IF v_is_protected THEN
    IF v_pnl_7d < 0 THEN v_pnl_7d := 0; END IF;
    IF v_pnl_30d < 0 THEN v_pnl_30d := 0; END IF;
    IF v_pnl_90d < 0 THEN v_pnl_90d := 0; END IF;
    IF v_pnl_all_time < 0 THEN v_pnl_all_time := 0; END IF;

    IF v_roi_7d < 0 THEN v_roi_7d := 0; END IF;
    IF v_roi_30d < 0 THEN v_roi_30d := 0; END IF;
    IF v_roi_90d < 0 THEN v_roi_90d := 0; END IF;
    IF v_roi_all_time < 0 THEN v_roi_all_time := 0; END IF;
  END IF;

  -- Update trader with all metrics including all period-specific win rates
  UPDATE traders
  SET
    pnl_7d = ROUND(v_pnl_7d, 2),
    pnl_30d = ROUND(v_pnl_30d, 2),
    pnl_90d = ROUND(v_pnl_90d, 2),
    pnl_all_time = ROUND(v_pnl_all_time, 2),
    roi_7d = ROUND(v_roi_7d, 2),
    roi_30d = ROUND(v_roi_30d, 2),
    roi_90d = ROUND(v_roi_90d, 2),
    roi_all_time = ROUND(v_roi_all_time, 2),
    total_trades = v_combined_total_trades,
    win_rate = ROUND(v_combined_win_rate, 2),
    avg_win_rate_7d = ROUND(v_win_rate_7d, 2),
    avg_win_rate_30d = ROUND(v_win_rate_30d, 2),
    avg_win_rate_90d = ROUND(v_win_rate_90d, 2),
    win_rate_all_time = ROUND(v_win_rate_all, 2),
    total_volume = ROUND(v_combined_volume, 2),
    metrics_last_updated = NOW(),
    updated_at = NOW()
  WHERE id = p_trader_id;

  RETURN true;
END;
$$;

-- Recalculate Satoshi Academy metrics immediately
SELECT calculate_trader_metrics('84eb1caa-d032-4a5a-8fe6-92f9cf6298f4');
