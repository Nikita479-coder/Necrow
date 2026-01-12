/*
  # Add Daily Follower Growth System

  1. Problem
    - Satoshi Academy should start with 2,468 followers
    - Followers should grow daily to show realistic platform growth

  2. Solution
    - Add base_followers column to store starting follower count
    - Add follower_growth_start_date to track when growth started
    - Add daily_follower_growth rate (followers gained per day)
    - Update calculate_trader_metrics to include follower growth

  3. Growth Logic
    - Base followers: 2,468 (starting point)
    - Daily growth: 5-15 followers per day (randomized but consistent per day)
    - Current followers = base_followers + (days_since_start * daily_rate)
*/

-- Add follower growth columns
ALTER TABLE traders
ADD COLUMN IF NOT EXISTS base_followers integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS follower_growth_start_date date DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS daily_follower_growth_rate integer DEFAULT 10;

-- Set Satoshi Academy's starting followers to 2468
UPDATE traders
SET 
  base_followers = 2468,
  followers_count = 2468,
  follower_growth_start_date = CURRENT_DATE,
  daily_follower_growth_rate = 12  -- Average ~12 new followers per day
WHERE name = 'Satoshi Academy';

-- Set other featured traders with appropriate base followers
UPDATE traders
SET 
  base_followers = followers_count,
  follower_growth_start_date = CURRENT_DATE,
  daily_follower_growth_rate = CASE 
    WHEN name = 'SatoshiFan' THEN 8
    WHEN name = 'c1ultra' THEN 10
    WHEN name = 'TogetherWin' THEN 15
    WHEN name = 'vipxmb' THEN 6
    WHEN name = 'CryptoKing' THEN 5
    ELSE 5
  END
WHERE is_featured = true
AND name != 'Satoshi Academy';

-- Create function to calculate current followers with daily growth
CREATE OR REPLACE FUNCTION calculate_current_followers(
  p_base_followers integer,
  p_start_date date,
  p_daily_rate integer,
  p_trader_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days_elapsed integer;
  v_daily_variance numeric;
  v_total_growth integer;
BEGIN
  -- Calculate days since growth started
  v_days_elapsed := CURRENT_DATE - p_start_date;
  
  IF v_days_elapsed < 0 THEN
    v_days_elapsed := 0;
  END IF;
  
  -- Get consistent daily variance for this trader (0.7 to 1.3 multiplier)
  v_daily_variance := 0.7 + (get_trader_daily_seed(p_trader_id, 'followers') * 0.6);
  
  -- Calculate total growth with variance
  v_total_growth := FLOOR(v_days_elapsed * p_daily_rate * v_daily_variance);
  
  RETURN p_base_followers + v_total_growth;
END;
$$;

-- Update calculate_trader_metrics to include follower growth
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
  
  -- Follower growth
  v_base_followers integer := 0;
  v_follower_start_date date;
  v_daily_follower_rate integer := 10;
  v_current_followers integer;

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
    COALESCE(base_roi_90d, 0),
    COALESCE(base_followers, followers_count),
    COALESCE(follower_growth_start_date, CURRENT_DATE),
    COALESCE(daily_follower_growth_rate, 10)
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
    v_base_roi_90d,
    v_base_followers,
    v_follower_start_date,
    v_daily_follower_rate
  FROM traders
  WHERE id = p_trader_id;

  IF v_starting_capital IS NULL THEN
    RETURN false;
  END IF;

  -- Calculate current followers with daily growth
  v_current_followers := calculate_current_followers(
    v_base_followers, 
    v_follower_start_date, 
    v_daily_follower_rate, 
    p_trader_id
  );

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
      followers_count = v_current_followers,
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
  v_combined_volume := v_base_volume + (v_actual_volume * v_multiplier);

  -- Calculate combined win rate
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

  -- Update trader with combined metrics including follower growth
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
    win_rate_all_time = ROUND(v_combined_win_rate, 2),
    total_volume = ROUND(v_combined_volume, 2),
    followers_count = v_current_followers,
    metrics_last_updated = NOW(),
    updated_at = NOW()
  WHERE id = p_trader_id;

  RETURN true;
END;
$$;

-- Recalculate all featured traders to apply new follower counts
DO $$
DECLARE
  v_trader_id uuid;
BEGIN
  FOR v_trader_id IN SELECT id FROM traders WHERE is_featured = true LOOP
    PERFORM calculate_trader_metrics(v_trader_id);
  END LOOP;
END;
$$;
