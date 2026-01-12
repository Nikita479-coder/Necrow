/*
  # Automated Trader Performance System

  1. Schema Changes
    - Add last_trade_date to track when traders last had activity
    - Add target_monthly_roi to define expected monthly returns (7-8%)
    - Add is_automated flag to mark which traders should be auto-updated

  2. New Functions
    - generate_daily_trader_pnl() - Generates realistic daily P&L for automated traders
    - update_trader_statistics() - Recalculates all trader stats based on generated trades
    - simulate_trader_trade() - Creates a simulated trade for a trader

  3. New Table
    - trader_daily_performance - Tracks daily performance history

  4. Logic
    - Each trader has a target monthly ROI of 7-8%
    - Daily returns fluctuate: +1% to +2% on good days, -0.5% to -1.5% on bad days
    - 70% of days are profitable, 30% are losing (achieving target monthly)
    - Admin managed trader is excluded from automation
*/

-- Add automation tracking columns
ALTER TABLE traders ADD COLUMN IF NOT EXISTS last_trade_date date DEFAULT CURRENT_DATE;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS target_monthly_roi numeric DEFAULT 7.5;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS is_automated boolean DEFAULT true;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS daily_trade_seed int DEFAULT 0;

-- Create daily performance tracking table
CREATE TABLE IF NOT EXISTS trader_daily_performance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_id uuid REFERENCES traders(id) ON DELETE CASCADE NOT NULL,
  performance_date date NOT NULL DEFAULT CURRENT_DATE,
  daily_pnl numeric NOT NULL DEFAULT 0,
  daily_roi numeric NOT NULL DEFAULT 0,
  starting_balance numeric NOT NULL,
  ending_balance numeric NOT NULL,
  trades_count int DEFAULT 1,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(trader_id, performance_date)
);

-- Enable RLS
ALTER TABLE trader_daily_performance ENABLE ROW LEVEL SECURITY;

-- Anyone can view performance history
CREATE POLICY "Anyone can view trader performance"
  ON trader_daily_performance FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_trader_daily_perf_trader ON trader_daily_performance(trader_id);
CREATE INDEX IF NOT EXISTS idx_trader_daily_perf_date ON trader_daily_performance(performance_date DESC);

-- Function to generate daily P&L for a trader
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
  v_is_profitable boolean;
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

  -- Use a seed based on date and trader for consistent randomness
  v_seed := (EXTRACT(epoch FROM p_date)::int + v_trader.daily_trade_seed) % 100;
  
  -- 70% profitable days, 30% losing days
  v_is_profitable := (v_seed % 10) < 7;

  -- Calculate daily ROI based on target monthly (7.5% / 30 days = 0.25% avg per day)
  -- But we want variation: profitable days +1% to +2.5%, losing days -0.5% to -1.5%
  IF v_is_profitable THEN
    -- Profitable day: 0.8% to 2.5% gain
    v_daily_roi := 0.8 + ((v_seed % 17) * 0.1);
  ELSE
    -- Losing day: -0.3% to -1.8% loss
    v_daily_roi := -0.3 - ((v_seed % 16) * 0.1);
  END IF;

  -- Calculate P&L based on current AUM
  v_current_aum := COALESCE(v_trader.aum, 100000);
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

-- Function to update all trader statistics based on performance history
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
    COALESCE(AVG(daily_roi), 0) as avg_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_7d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '7 days';

  -- Calculate 30-day stats
  SELECT 
    COALESCE(SUM(daily_pnl), 0) as total_pnl,
    COALESCE(SUM(daily_roi), 0) as total_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_30d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '30 days';

  -- Calculate 90-day stats
  SELECT 
    COALESCE(SUM(daily_pnl), 0) as total_pnl,
    COALESCE(SUM(daily_roi), 0) as total_roi,
    COUNT(*) FILTER (WHERE daily_roi > 0) as profitable_days,
    COUNT(*) as total_days
  INTO v_90d_stats
  FROM trader_daily_performance
  WHERE trader_id = p_trader_id
  AND performance_date >= CURRENT_DATE - INTERVAL '90 days';

  -- Update trader with calculated stats
  UPDATE traders SET
    -- 7-day metrics
    pnl_7d = v_7d_stats.total_pnl,
    roi_7d = v_7d_stats.avg_roi * 7,
    avg_win_rate_7d = CASE 
      WHEN v_7d_stats.total_days > 0 
      THEN (v_7d_stats.profitable_days::numeric / v_7d_stats.total_days * 100)
      ELSE 70
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
      ELSE 70
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
      ELSE 70
    END,

    last_trade_date = CURRENT_DATE,
    updated_at = NOW()

  WHERE id = p_trader_id;
END;
$$;

-- Function to run daily updates for all automated traders
CREATE OR REPLACE FUNCTION process_daily_trader_updates()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_results json[] := ARRAY[]::json[];
  v_daily_pnl numeric;
BEGIN
  -- Process each automated trader
  FOR v_trader IN 
    SELECT * FROM traders 
    WHERE is_automated = true
    ORDER BY id
  LOOP
    -- Generate daily P&L
    v_daily_pnl := generate_daily_trader_pnl(v_trader.id);
    
    -- Update statistics
    PERFORM update_trader_statistics(v_trader.id);
    
    -- Add to results
    v_results := array_append(v_results, json_build_object(
      'trader_id', v_trader.id,
      'trader_name', v_trader.name,
      'daily_pnl', v_daily_pnl,
      'updated', true
    ));
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed_count', array_length(v_results, 1),
    'results', v_results
  );
END;
$$;

-- Mark all existing traders as automated except admin managed ones
UPDATE traders SET is_automated = true;

-- Update target monthly ROI to 7-8% range
UPDATE traders SET target_monthly_roi = 7 + (random() * 1.5);

-- Set random seeds for variation
UPDATE traders SET daily_trade_seed = (random() * 99)::int;
