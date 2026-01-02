/*
  # Fix calculate_trader_metrics to include base PNL and ROI

  1. Changes
    - Add base_pnl_7d, base_pnl_30d, base_pnl_90d to period PNL
    - Add base_roi_7d, base_roi_30d, base_roi_90d to period ROI
    - Actual trades add on top of these base values
*/

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

  -- Base values
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

  -- Actual trade stats
  v_actual_total_trades integer := 0;
  v_actual_winning_trades integer := 0;
  v_actual_volume numeric := 0;
  v_actual_pnl_7d numeric := 0;
  v_actual_pnl_30d numeric := 0;
  v_actual_pnl_90d numeric := 0;
  v_actual_pnl_all numeric := 0;

  -- Combined stats
  v_combined_total_trades integer;
  v_combined_winning_trades integer;
  v_combined_win_rate numeric;
  v_combined_volume numeric;
BEGIN
  SELECT 
    starting_capital, 
    protected_trader, 
    is_automated, 
    target_monthly_roi,
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

  -- FOR AUTOMATED TRADERS: Use target ROI (unchanged)
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
  v_cutoff_7d := NOW() - INTERVAL '7 days';
  v_cutoff_30d := NOW() - INTERVAL '30 days';
  v_cutoff_90d := NOW() - INTERVAL '90 days';

  -- Get actual trade statistics
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE pnl > 0),
    COALESCE(SUM(ABS(pnl) * COALESCE(leverage, 1)), 0)
  INTO v_actual_total_trades, v_actual_winning_trades, v_actual_volume
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed';

  -- Combine with base values
  v_combined_total_trades := v_base_total_trades + v_actual_total_trades;
  v_combined_winning_trades := v_base_winning_trades + v_actual_winning_trades;
  v_combined_volume := v_base_volume + v_actual_volume;

  -- Calculate combined win rate
  IF v_combined_total_trades > 0 THEN
    v_combined_win_rate := (v_combined_winning_trades::numeric / v_combined_total_trades::numeric) * 100;
  ELSE
    v_combined_win_rate := 0;
  END IF;

  -- Calculate actual period P&L
  SELECT COALESCE(SUM(pnl), 0) INTO v_actual_pnl_7d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_7d;

  SELECT COALESCE(SUM(pnl), 0) INTO v_actual_pnl_30d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_30d;

  SELECT COALESCE(SUM(pnl), 0) INTO v_actual_pnl_90d
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL
    AND closed_at >= v_cutoff_90d;

  SELECT COALESCE(SUM(pnl), 0) INTO v_actual_pnl_all
  FROM trader_trades
  WHERE trader_id = p_trader_id
    AND status = 'closed'
    AND closed_at IS NOT NULL;

  -- Add base values to actual values
  v_pnl_7d := v_base_pnl_7d + v_actual_pnl_7d;
  v_pnl_30d := v_base_pnl_30d + v_actual_pnl_30d;
  v_pnl_90d := v_base_pnl_90d + v_actual_pnl_90d;
  v_pnl_all_time := v_base_pnl + v_base_pnl_90d + v_actual_pnl_all;

  -- Calculate ROI: base ROI + actual ROI contribution
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

  -- Update trader with combined metrics
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
    total_trades = v_combined_total_trades,
    win_rate = v_combined_win_rate,
    win_rate_all_time = v_combined_win_rate,
    total_volume = v_combined_volume,
    metrics_last_updated = NOW(),
    updated_at = NOW()
  WHERE id = p_trader_id;

  RETURN true;
END;
$$;
