/*
  # Create Calculate Trader Metrics Function

  1. Function Overview
    - `calculate_trader_metrics(p_trader_id uuid)` - Calculates all trader performance metrics based on actual trade data
    
  2. Calculation Logic
    - Fetches all closed trades from trader_trades table ordered by closed_at
    - For each time period (7D, 30D, 90D, All Time):
      - Calculates date cutoff (NOW() - period days)
      - Gets cumulative P&L from trades BEFORE the period start
      - Computes period capital base as: starting_capital + cumulative_pre_period_pnl
      - Sums realized_pnl for trades within the period window
      - Calculates ROI: (period_pnl / period_capital_base) * 100
      - For protected traders: ensures ROI and P&L never go below 0
    
  3. Time Windows
    - 7D: Last 7 days (rolling window)
    - 30D: Last 30 days (rolling window)
    - 90D: Last 90 days (rolling window)
    - All Time: From first trade to now
    
  4. Protected Traders
    - Traders marked as protected_trader = true (like Satoshi Academy)
    - Their metrics are capped at 0 minimum (no negative values shown)
    - This maintains a positive public image while showing realistic data for others
    
  5. Updates
    - Updates all metric columns in traders table
    - Sets metrics_last_updated timestamp
    - Returns true on success, false if trader not found
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
  v_starting_capital numeric;
  
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
  SELECT starting_capital, protected_trader
  INTO v_starting_capital, v_is_protected
  FROM traders
  WHERE id = p_trader_id;
  
  -- Return false if trader not found
  IF v_starting_capital IS NULL THEN
    RETURN false;
  END IF;
  
  -- Calculate time period cutoffs
  v_cutoff_7d := NOW() - INTERVAL '7 days';
  v_cutoff_30d := NOW() - INTERVAL '30 days';
  v_cutoff_90d := NOW() - INTERVAL '90 days';
  
  -- Calculate pre-period cumulative P&L (trades that closed BEFORE the period)
  -- This represents the capital accumulated before each time window
  
  -- Pre-7D: All trades closed before 7 days ago
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_7d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_7d;
  
  -- Pre-30D: All trades closed before 30 days ago
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_30d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_30d;
  
  -- Pre-90D: All trades closed before 90 days ago
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pre_90d_pnl
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at < v_cutoff_90d;
  
  -- Calculate capital bases (starting capital + accumulated P&L before period)
  v_capital_7d := v_starting_capital + v_pre_7d_pnl;
  v_capital_30d := v_starting_capital + v_pre_30d_pnl;
  v_capital_90d := v_starting_capital + v_pre_90d_pnl;
  v_capital_all_time := v_starting_capital;
  
  -- Ensure capital bases are never zero or negative (would cause division errors)
  IF v_capital_7d <= 0 THEN v_capital_7d := v_starting_capital; END IF;
  IF v_capital_30d <= 0 THEN v_capital_30d := v_starting_capital; END IF;
  IF v_capital_90d <= 0 THEN v_capital_90d := v_starting_capital; END IF;
  
  -- Calculate period P&L (trades within each time window)
  
  -- 7D P&L: Trades closed in last 7 days
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_7d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_7d;
  
  -- 30D P&L: Trades closed in last 30 days
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_30d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_30d;
  
  -- 90D P&L: Trades closed in last 90 days
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_90d
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL
  AND closed_at >= v_cutoff_90d;
  
  -- All Time P&L: All closed trades
  SELECT COALESCE(SUM(realized_pnl), 0) INTO v_pnl_all_time
  FROM trader_trades
  WHERE trader_id = p_trader_id
  AND status = 'closed'
  AND closed_at IS NOT NULL;
  
  -- Calculate ROI for each period
  v_roi_7d := (v_pnl_7d / v_capital_7d) * 100;
  v_roi_30d := (v_pnl_30d / v_capital_30d) * 100;
  v_roi_90d := (v_pnl_90d / v_capital_90d) * 100;
  v_roi_all_time := (v_pnl_all_time / v_capital_all_time) * 100;
  
  -- Apply protection for protected traders (cap at 0 minimum)
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
  
  -- Update traders table with calculated metrics
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION calculate_trader_metrics TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION calculate_trader_metrics IS 'Calculates all trader performance metrics based on actual trade data from trader_trades table. Supports rolling time windows and protected trader logic.';
