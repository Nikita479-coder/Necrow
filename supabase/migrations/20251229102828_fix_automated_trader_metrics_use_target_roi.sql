/*
  # Fix Automated Trader Metrics to Use Target ROI
  
  1. Problem
    - Automated traders have configured target_monthly_roi (e.g., 10%, 20%, 200%)
    - The calculate_trader_metrics() function recalculates from actual trades
    - This overwrites the target values with tiny calculated values
    
  2. Solution
    - Modify calculate_trader_metrics() to check if trader is automated
    - For automated traders: Use target_monthly_roi and calculate proportional PNL
    - For regular traders: Calculate normally from actual trades
    
  3. Target Values for Automated Traders
    - ROI 30D = target_monthly_roi (as configured, e.g., 10%, 20%)
    - ROI 7D = target_monthly_roi / 4.3 (weekly)
    - ROI 90D = target_monthly_roi * 3 (3 months)
    - ROI All Time = target_monthly_roi * 6 (6 months)
    - PNL calculated as: starting_capital * (ROI / 100)
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
  
  -- Time period cutoffs
  v_cutoff_7d timestamptz;
  v_cutoff_30d timestamptz;
  v_cutoff_90d timestamptz;
  
  -- Pre-period cumulative P&L (for capital base calculation)
  v_pre_7d_pnl numeric := 0;
  v_pre_30d_pnl numeric := 0;
  v_pre_90d_pnl numeric := 0;
  
  -- Period P&L
  v_pnl_7d numeric := 0;
  v_pnl_30d numeric := 0;
  v_pnl_90d numeric := 0;
  v_pnl_all_time numeric := 0;
  
  -- ROI calculations
  v_roi_7d numeric := 0;
  v_roi_30d numeric := 0;
  v_roi_90d numeric := 0;
  v_roi_all_time numeric := 0;
  
  -- Capital bases
  v_capital_7d numeric;
  v_capital_30d numeric;
  v_capital_90d numeric;
  v_capital_all_time numeric;
BEGIN
  -- Get trader info
  SELECT starting_capital, protected_trader, is_automated, target_monthly_roi
  INTO v_starting_capital, v_is_protected, v_is_automated, v_target_roi
  FROM traders
  WHERE id = p_trader_id;
  
  -- Return false if trader not found
  IF v_starting_capital IS NULL THEN
    RETURN false;
  END IF;
  
  -- FOR AUTOMATED TRADERS: Use target ROI instead of calculating from trades
  IF v_is_automated = true AND v_target_roi IS NOT NULL THEN
    -- Use configured target values
    v_roi_30d := v_target_roi;
    v_pnl_30d := (v_starting_capital * (v_target_roi / 100));
    
    v_roi_7d := v_target_roi / 4.3;  -- Weekly ROI (30 days / 7 days ≈ 4.3)
    v_pnl_7d := (v_starting_capital * ((v_target_roi / 100) / 4.3));
    
    v_roi_90d := v_target_roi * 3;  -- 3 months
    v_pnl_90d := (v_starting_capital * ((v_target_roi / 100) * 3));
    
    v_roi_all_time := CASE 
      WHEN v_target_roi > 0 THEN v_target_roi * 6  -- 6 months
      ELSE v_target_roi * 2  -- Only 2 months for negative performers
    END;
    v_pnl_all_time := CASE
      WHEN v_target_roi > 0 THEN (v_starting_capital * ((v_target_roi / 100) * 6))
      ELSE (v_starting_capital * ((v_target_roi / 100) * 2))
    END;
    
    -- Apply protection if needed
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
    
    -- Update and return
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
  
  -- FOR REGULAR TRADERS: Calculate from actual trades
  
  -- Calculate time period cutoffs
  v_cutoff_7d := NOW() - INTERVAL '7 days';
  v_cutoff_30d := NOW() - INTERVAL '30 days';
  v_cutoff_90d := NOW() - INTERVAL '90 days';
  
  -- Calculate pre-period cumulative P&L
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_7d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_7d;
  
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_30d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_30d;
  
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_90d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_90d;
  
  -- Calculate capital bases
  v_capital_7d := v_starting_capital + v_pre_7d_pnl;
  v_capital_30d := v_starting_capital + v_pre_30d_pnl;
  v_capital_90d := v_starting_capital + v_pre_90d_pnl;
  v_capital_all_time := v_starting_capital;
  
  -- Ensure capital bases are never zero or negative
  IF v_capital_7d <= 0 THEN v_capital_7d := v_starting_capital; END IF;
  IF v_capital_30d <= 0 THEN v_capital_30d := v_starting_capital; END IF;
  IF v_capital_90d <= 0 THEN v_capital_90d := v_starting_capital; END IF;
  
  -- Calculate period P&L
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_7d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_7d;
  
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_30d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_30d;
  
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_90d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_90d;
  
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_all_time
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL;
  
  -- Calculate ROI
  v_roi_7d := (v_pnl_7d / v_capital_7d) * 100;
  v_roi_30d := (v_pnl_30d / v_capital_30d) * 100;
  v_roi_90d := (v_pnl_90d / v_capital_90d) * 100;
  v_roi_all_time := (v_pnl_all_time / v_capital_all_time) * 100;
  
  -- Apply protection
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
  
  -- Update traders table
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
END;
$$;
