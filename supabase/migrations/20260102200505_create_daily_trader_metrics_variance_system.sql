/*
  # Daily Trader Metrics Variance System

  1. New Function
    - `update_trader_daily_metrics` - Applies daily variance to all trader metrics
    - Keeps metrics around the same % but varies them daily for realism

  2. Variance Rules
    - ROI: Varies +/- 15% of target
    - PNL: Calculated from varied ROI
    - AUM: Varies +/- 5%
    - MDD: Varies +/- 15%
    - Sharpe Ratio: Varies +/- 20%
    - Followers: +/- 1-5%
    - Rank: Small movement within bounds

  3. Notes
    - Uses date-based seed for consistent daily values
    - Each trader gets unique variance based on their ID
*/

-- Function to generate consistent daily random value for a trader
CREATE OR REPLACE FUNCTION get_trader_daily_seed(p_trader_id uuid, p_metric text)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seed_string text;
  v_hash bytea;
  v_value numeric;
BEGIN
  v_seed_string := p_trader_id::text || CURRENT_DATE::text || p_metric;
  v_hash := sha256(v_seed_string::bytea);
  v_value := (get_byte(v_hash, 0) + get_byte(v_hash, 1) * 256) / 65535.0;
  RETURN v_value;
END;
$$;

-- Main function to update all trader metrics with daily variance
CREATE OR REPLACE FUNCTION update_all_trader_metrics_with_variance()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_count integer := 0;
  
  v_roi_variance numeric;
  v_aum_variance numeric;
  v_mdd_variance numeric;
  v_sharpe_variance numeric;
  v_follower_variance numeric;
  v_rank_variance numeric;
  
  v_new_roi numeric;
  v_new_pnl numeric;
  v_new_aum numeric;
  v_new_mdd numeric;
  v_new_sharpe numeric;
  v_new_followers integer;
  v_new_rank integer;
  
  v_base_aum numeric;
  v_base_mdd numeric;
  v_base_sharpe numeric;
  v_base_followers integer;
BEGIN
  FOR v_trader IN
    SELECT 
      t.id,
      t.name,
      t.target_monthly_roi,
      t.starting_capital,
      t.aum,
      t.mdd_30d,
      t.sharpe_ratio,
      t.followers_count,
      t.rank,
      t.total_rank,
      t.is_automated,
      t.protected_trader
    FROM traders t
    WHERE t.is_featured = true
    ORDER BY t.target_monthly_roi DESC NULLS LAST
  LOOP
    -- Skip non-automated traders
    IF v_trader.is_automated IS NOT TRUE THEN
      CONTINUE;
    END IF;
    
    -- Generate daily variance values (0 to 1, convert to -0.5 to +0.5 range, then scale)
    v_roi_variance := (get_trader_daily_seed(v_trader.id, 'roi') - 0.5) * 0.30;  -- +/- 15%
    v_aum_variance := (get_trader_daily_seed(v_trader.id, 'aum') - 0.5) * 0.10;  -- +/- 5%
    v_mdd_variance := (get_trader_daily_seed(v_trader.id, 'mdd') - 0.5) * 0.30;  -- +/- 15%
    v_sharpe_variance := (get_trader_daily_seed(v_trader.id, 'sharpe') - 0.5) * 0.40;  -- +/- 20%
    v_follower_variance := (get_trader_daily_seed(v_trader.id, 'followers') - 0.5) * 0.06;  -- +/- 3%
    v_rank_variance := (get_trader_daily_seed(v_trader.id, 'rank') - 0.5) * 0.20;  -- +/- 10%

    -- Calculate new ROI with variance around target
    IF v_trader.target_monthly_roi IS NOT NULL THEN
      v_new_roi := v_trader.target_monthly_roi * (1 + v_roi_variance);
      
      -- Protected traders can't go negative
      IF v_trader.protected_trader AND v_new_roi < 0 THEN
        v_new_roi := ABS(v_new_roi) * 0.1;  -- Small positive instead
      END IF;
    ELSE
      v_new_roi := 0;
    END IF;
    
    -- Calculate PNL based on varied ROI
    IF v_trader.starting_capital IS NOT NULL AND v_trader.starting_capital > 0 THEN
      v_new_pnl := v_trader.starting_capital * (v_new_roi / 100);
    ELSE
      v_new_pnl := 0;
    END IF;
    
    -- Calculate new AUM with variance
    v_base_aum := COALESCE(v_trader.aum, v_trader.starting_capital, 10000000);
    v_new_aum := v_base_aum * (1 + v_aum_variance);
    IF v_new_aum < 100000 THEN v_new_aum := 100000; END IF;
    
    -- Calculate new MDD with variance (keep between 0 and 60)
    v_base_mdd := COALESCE(v_trader.mdd_30d, 15);
    v_new_mdd := v_base_mdd * (1 + v_mdd_variance);
    IF v_new_mdd < 0 THEN v_new_mdd := 0; END IF;
    IF v_new_mdd > 60 THEN v_new_mdd := 60; END IF;
    
    -- Calculate new Sharpe Ratio with variance
    v_base_sharpe := COALESCE(v_trader.sharpe_ratio, 1.5);
    IF v_base_sharpe > 0 THEN
      v_new_sharpe := v_base_sharpe * (1 + v_sharpe_variance);
      IF v_new_sharpe < 0.1 THEN v_new_sharpe := 0.1; END IF;
      IF v_new_sharpe > 7 THEN v_new_sharpe := 7; END IF;
    ELSE
      v_new_sharpe := v_base_sharpe;
    END IF;
    
    -- Calculate new followers with variance
    v_base_followers := COALESCE(v_trader.followers_count, 100);
    v_new_followers := GREATEST(10, ROUND(v_base_followers * (1 + v_follower_variance))::integer);
    
    -- Calculate new rank with variance (stay within total_rank bounds)
    IF v_trader.rank IS NOT NULL AND v_trader.total_rank IS NOT NULL THEN
      v_new_rank := GREATEST(1, LEAST(v_trader.total_rank, 
        ROUND(v_trader.rank * (1 + v_rank_variance))::integer));
    ELSE
      v_new_rank := v_trader.rank;
    END IF;
    
    -- Update the trader
    UPDATE traders
    SET
      roi_30d = ROUND(v_new_roi, 2),
      pnl_30d = ROUND(v_new_pnl, 2),
      roi_7d = ROUND(v_new_roi / 4.3, 2),
      pnl_7d = ROUND(v_new_pnl / 4.3, 2),
      roi_90d = ROUND(v_new_roi * 3, 2),
      pnl_90d = ROUND(v_new_pnl * 3, 2),
      roi_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_roi * 6 ELSE v_new_roi * 2 END, 2),
      pnl_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_pnl * 6 ELSE v_new_pnl * 2 END, 2),
      aum = ROUND(v_new_aum, 2),
      mdd_30d = ROUND(v_new_mdd, 2),
      sharpe_ratio = ROUND(v_new_sharpe, 2),
      followers_count = v_new_followers,
      rank = v_new_rank,
      metrics_last_updated = NOW(),
      updated_at = NOW()
    WHERE id = v_trader.id;
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'traders_updated', v_count,
    'date', CURRENT_DATE,
    'message', format('Updated %s traders with daily variance', v_count)
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_all_trader_metrics_with_variance() TO authenticated;
GRANT EXECUTE ON FUNCTION update_all_trader_metrics_with_variance() TO service_role;
GRANT EXECUTE ON FUNCTION get_trader_daily_seed(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_trader_daily_seed(uuid, text) TO service_role;
