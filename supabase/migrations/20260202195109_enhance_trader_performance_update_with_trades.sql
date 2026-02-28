/*
  # Enhance Trader Performance Update to Create Trades and Update All Stats
  
  ## Changes
  1. Creates 3 synthetic trades per automated trader when called
  2. Updates ALL trading statistics including:
     - Total Trades, Win Rate
     - Current/Max Win Streak
     - Profitable Days
     - Best/Worst Trade
     - Avg Hold Time, Avg Leverage
     - Sharpe Ratio, MDD, Volatility, Consistency
     - Monthly Return, Total Volume
  
  ## Notes
  - Each call adds 3 new closed trades per automated trader
  - Trades are varied in P&L to create realistic statistics
  - Win/loss ratio kept around 60-70% to maintain positive stats
*/

-- Function to generate random number in range with seed
CREATE OR REPLACE FUNCTION get_seeded_random(p_seed text, p_min numeric, p_max numeric)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hash bytea;
  v_value numeric;
BEGIN
  v_hash := sha256((p_seed || extract(epoch from now())::text)::bytea);
  v_value := (get_byte(v_hash, 0) + get_byte(v_hash, 1) * 256 + get_byte(v_hash, 2) * 65536) / 16777215.0;
  RETURN p_min + (v_value * (p_max - p_min));
END;
$$;

-- Enhanced function that creates trades and updates ALL stats
CREATE OR REPLACE FUNCTION update_all_trader_metrics_with_variance()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_count integer := 0;
  v_trades_created integer := 0;
  
  v_trade_pnl numeric;
  v_trade_side text;
  v_trade_pair text;
  v_trade_leverage integer;
  v_trade_entry numeric;
  v_trade_exit numeric;
  v_trade_size numeric;
  v_trade_margin numeric;
  v_is_win boolean;
  
  v_pairs text[] := ARRAY['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'XRPUSDT', 'DOGEUSDT', 'AVAXUSDT', 'ADAUSDT'];
  v_sides text[] := ARRAY['long', 'short'];
  
  v_total_trades integer;
  v_winning_trades integer;
  v_current_streak integer;
  v_max_streak integer;
  v_profitable_days integer;
  v_total_days integer;
  v_best_trade numeric;
  v_worst_trade numeric;
  v_avg_leverage numeric;
  v_total_volume numeric;
  v_total_pnl numeric;
  
  v_roi_variance numeric;
  v_aum_variance numeric;
  v_mdd_variance numeric;
  v_sharpe_variance numeric;
  v_follower_variance numeric;
  
  v_new_roi numeric;
  v_new_pnl numeric;
  v_new_aum numeric;
  v_new_mdd numeric;
  v_new_sharpe numeric;
  v_new_followers integer;
  v_new_volatility numeric;
  v_new_consistency numeric;
  v_monthly_return numeric;
  
  i integer;
BEGIN
  -- Process each automated featured trader
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
      t.total_trades,
      t.win_rate,
      t.current_win_streak,
      t.max_win_streak,
      t.profitable_days,
      t.total_days,
      t.best_trade,
      t.worst_trade,
      t.avg_leverage,
      t.total_volume,
      t.volatility_score,
      t.consistency_score,
      t.monthly_return,
      t.is_automated,
      t.protected_trader,
      COALESCE(t.trade_pnl_multiplier, 1) as multiplier
    FROM traders t
    WHERE t.is_featured = true
      AND t.is_automated = true
    ORDER BY t.name
  LOOP
    
    -- Create 3 new trades for this trader
    FOR i IN 1..3 LOOP
      -- Determine if this trade is a win (70% chance for automated traders)
      v_is_win := get_seeded_random(v_trader.id::text || i::text || 'win', 0, 100) < 70;
      
      -- Random trade parameters
      v_trade_pair := v_pairs[1 + floor(get_seeded_random(v_trader.id::text || i::text || 'pair', 0, array_length(v_pairs, 1)))::integer];
      v_trade_side := v_sides[1 + floor(get_seeded_random(v_trader.id::text || i::text || 'side', 0, 2))::integer];
      v_trade_leverage := floor(get_seeded_random(v_trader.id::text || i::text || 'lev', 3, 20))::integer;
      
      -- Generate P&L based on win/loss and trader's profile
      IF v_is_win THEN
        -- Win: +$100 to +$5000 (multiplied by trader's multiplier)
        v_trade_pnl := get_seeded_random(v_trader.id::text || i::text || 'pnl', 100, 5000) * v_trader.multiplier;
      ELSE
        -- Loss: -$50 to -$2000 (multiplied by trader's multiplier)
        v_trade_pnl := -1 * get_seeded_random(v_trader.id::text || i::text || 'pnl', 50, 2000) * v_trader.multiplier;
      END IF;
      
      -- Calculate trade size and margin
      v_trade_margin := ABS(v_trade_pnl) * (get_seeded_random(v_trader.id::text || i::text || 'margin', 2, 5));
      v_trade_size := v_trade_margin * v_trade_leverage;
      
      -- Entry/exit prices (approximate)
      v_trade_entry := CASE 
        WHEN v_trade_pair = 'BTCUSDT' THEN get_seeded_random(v_trader.id::text || i::text || 'entry', 95000, 105000)
        WHEN v_trade_pair = 'ETHUSDT' THEN get_seeded_random(v_trader.id::text || i::text || 'entry', 3200, 3600)
        WHEN v_trade_pair = 'SOLUSDT' THEN get_seeded_random(v_trader.id::text || i::text || 'entry', 200, 250)
        WHEN v_trade_pair = 'BNBUSDT' THEN get_seeded_random(v_trader.id::text || i::text || 'entry', 650, 750)
        ELSE get_seeded_random(v_trader.id::text || i::text || 'entry', 1, 100)
      END;
      
      -- Exit price based on P&L direction
      IF v_trade_side = 'long' THEN
        v_trade_exit := v_trade_entry * (1 + (v_trade_pnl / v_trade_size));
      ELSE
        v_trade_exit := v_trade_entry * (1 - (v_trade_pnl / v_trade_size));
      END IF;
      
      -- Insert the trade
      INSERT INTO trader_trades (
        trader_id,
        symbol,
        side,
        entry_price,
        exit_price,
        size,
        margin,
        leverage,
        pnl,
        roe,
        status,
        source,
        opened_at,
        closed_at,
        created_at,
        updated_at
      ) VALUES (
        v_trader.id,
        v_trade_pair,
        v_trade_side,
        ROUND(v_trade_entry, 2),
        ROUND(v_trade_exit, 2),
        ROUND(v_trade_size, 2),
        ROUND(v_trade_margin, 2),
        v_trade_leverage,
        ROUND(v_trade_pnl, 2),
        ROUND((v_trade_pnl / v_trade_margin) * 100, 2),
        'closed',
        'admin',
        NOW() - (random() * INTERVAL '48 hours'),
        NOW() - (random() * INTERVAL '2 hours'),
        NOW(),
        NOW()
      );
      
      v_trades_created := v_trades_created + 1;
    END LOOP;
    
    -- Now calculate updated statistics from ALL trades
    SELECT 
      COUNT(*),
      COUNT(*) FILTER (WHERE pnl > 0),
      COALESCE(MAX(pnl), 0),
      COALESCE(MIN(pnl), 0),
      COALESCE(AVG(leverage), 10),
      COALESCE(SUM(ABS(size)), 0),
      COALESCE(SUM(pnl), 0)
    INTO 
      v_total_trades,
      v_winning_trades,
      v_best_trade,
      v_worst_trade,
      v_avg_leverage,
      v_total_volume,
      v_total_pnl
    FROM trader_trades
    WHERE trader_id = v_trader.id
      AND status = 'closed';
    
    -- Calculate current win streak (from most recent trades)
    SELECT COUNT(*) INTO v_current_streak
    FROM (
      SELECT pnl,
             ROW_NUMBER() OVER (ORDER BY closed_at DESC) as rn
      FROM trader_trades
      WHERE trader_id = v_trader.id
        AND status = 'closed'
        AND closed_at IS NOT NULL
      ORDER BY closed_at DESC
    ) recent_trades
    WHERE rn <= (
      SELECT MIN(rn) - 1
      FROM (
        SELECT pnl,
               ROW_NUMBER() OVER (ORDER BY closed_at DESC) as rn
        FROM trader_trades
        WHERE trader_id = v_trader.id
          AND status = 'closed'
          AND closed_at IS NOT NULL
      ) t
      WHERE pnl <= 0
    ) OR NOT EXISTS (
      SELECT 1 FROM trader_trades 
      WHERE trader_id = v_trader.id 
        AND status = 'closed' 
        AND pnl <= 0
    );
    
    -- Set a reasonable current streak if calculation failed
    IF v_current_streak IS NULL OR v_current_streak = 0 THEN
      v_current_streak := floor(get_seeded_random(v_trader.id::text || 'streak', 1, 8))::integer;
    END IF;
    
    -- Max win streak should be at least current streak
    v_max_streak := GREATEST(
      COALESCE(v_trader.max_win_streak, 10),
      v_current_streak,
      floor(get_seeded_random(v_trader.id::text || 'maxstreak', 8, 25))::integer
    );
    
    -- Calculate profitable days (based on win rate)
    v_total_days := GREATEST(30, COALESCE(v_trader.total_days, 32));
    v_profitable_days := GREATEST(
      floor(v_total_days * (v_winning_trades::numeric / GREATEST(v_total_trades, 1)))::integer,
      floor(v_total_days * 0.55)::integer
    );
    
    -- Generate variance for other metrics
    v_roi_variance := (get_seeded_random(v_trader.id::text || 'roi', 0, 1) - 0.5) * 0.30;
    v_aum_variance := (get_seeded_random(v_trader.id::text || 'aum', 0, 1) - 0.5) * 0.10;
    v_mdd_variance := (get_seeded_random(v_trader.id::text || 'mdd', 0, 1) - 0.5) * 0.30;
    v_sharpe_variance := (get_seeded_random(v_trader.id::text || 'sharpe', 0, 1) - 0.5) * 0.40;
    v_follower_variance := (get_seeded_random(v_trader.id::text || 'followers', 0, 1) - 0.5) * 0.06;
    
    -- Calculate new values
    IF v_trader.target_monthly_roi IS NOT NULL THEN
      v_new_roi := v_trader.target_monthly_roi * (1 + v_roi_variance);
      IF v_trader.protected_trader AND v_new_roi < 0 THEN
        v_new_roi := ABS(v_new_roi) * 0.1;
      END IF;
    ELSE
      v_new_roi := 15;
    END IF;
    
    v_new_pnl := COALESCE(v_trader.starting_capital, 10000000) * (v_new_roi / 100);
    v_new_aum := COALESCE(v_trader.aum, 10000000) * (1 + v_aum_variance);
    v_new_mdd := GREATEST(1, LEAST(60, COALESCE(v_trader.mdd_30d, 10) * (1 + v_mdd_variance)));
    v_new_sharpe := GREATEST(0.5, LEAST(5, COALESCE(v_trader.sharpe_ratio, 2) * (1 + v_sharpe_variance)));
    v_new_followers := GREATEST(50, ROUND(COALESCE(v_trader.followers_count, 500) * (1 + v_follower_variance))::integer);
    v_new_volatility := GREATEST(5, LEAST(30, COALESCE(v_trader.volatility_score, 15) + get_seeded_random(v_trader.id::text || 'vol', -3, 3)));
    v_new_consistency := GREATEST(50, LEAST(95, COALESCE(v_trader.consistency_score, 70) + get_seeded_random(v_trader.id::text || 'cons', -5, 5)));
    v_monthly_return := v_new_roi / 30 * (1 + get_seeded_random(v_trader.id::text || 'monthly', -0.2, 0.2));
    
    -- Update trader with ALL new stats
    UPDATE traders
    SET
      -- Trade statistics
      total_trades = v_total_trades,
      win_rate = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100, 1) ELSE 50 END,
      win_rate_7d = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100 + get_seeded_random(v_trader.id::text || 'wr7d', -5, 5), 1) ELSE 50 END,
      win_rate_30d = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100 + get_seeded_random(v_trader.id::text || 'wr30d', -3, 3), 1) ELSE 50 END,
      win_rate_all_time = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100, 1) ELSE 50 END,
      current_win_streak = v_current_streak,
      max_win_streak = v_max_streak,
      profitable_days = v_profitable_days,
      total_days = v_total_days,
      best_trade = ROUND(v_best_trade, 2),
      worst_trade = ROUND(v_worst_trade, 2),
      avg_leverage = ROUND(v_avg_leverage, 1),
      total_volume = ROUND(v_total_volume, 2),
      
      -- ROI/PNL metrics
      roi_7d = ROUND(v_new_roi / 4.3, 2),
      roi_30d = ROUND(v_new_roi, 2),
      roi_90d = ROUND(v_new_roi * 3, 2),
      roi_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_roi * 6 ELSE v_new_roi * 2 END, 2),
      pnl_7d = ROUND(v_new_pnl / 4.3, 2),
      pnl_30d = ROUND(v_new_pnl, 2),
      pnl_90d = ROUND(v_new_pnl * 3, 2),
      pnl_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_pnl * 6 ELSE v_new_pnl * 2 END, 2),
      
      -- Risk metrics
      aum = ROUND(v_new_aum, 2),
      mdd_30d = ROUND(v_new_mdd, 2),
      sharpe_ratio = ROUND(v_new_sharpe, 2),
      volatility_score = ROUND(v_new_volatility, 1),
      consistency_score = ROUND(v_new_consistency, 1),
      monthly_return = ROUND(v_monthly_return, 2),
      
      -- Followers
      followers_count = v_new_followers,
      
      -- Timestamps
      metrics_last_updated = NOW(),
      updated_at = NOW()
    WHERE id = v_trader.id;
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'traders_updated', v_count,
    'trades_created', v_trades_created,
    'date', CURRENT_DATE,
    'timestamp', NOW(),
    'message', format('Updated %s traders, created %s new trades', v_count, v_trades_created)
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_all_trader_metrics_with_variance() TO authenticated;
GRANT EXECUTE ON FUNCTION update_all_trader_metrics_with_variance() TO service_role;
GRANT EXECUTE ON FUNCTION get_seeded_random(text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION get_seeded_random(text, numeric, numeric) TO service_role;