/*
  # Fix Trader Performance Update - Correct Trade Table Columns
  
  ## Fixes
  - size -> quantity
  - margin -> margin_used
  - roe -> pnl_percent
  - Remove source column (doesn't exist)
*/

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
  v_trade_quantity numeric;
  v_trade_margin numeric;
  v_is_win boolean;
  
  v_pairs text[] := ARRAY['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'XRPUSDT', 'DOGEUSDT', 'AVAXUSDT', 'ADAUSDT'];
  v_sides text[] := ARRAY['long', 'short'];
  
  v_total_trades integer;
  v_winning_trades integer;
  v_current_streak integer;
  v_max_streak integer;
  v_profitable_days integer;
  v_trading_days integer;
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
      t.win_streak,
      t.max_win_streak,
      t.profitable_days,
      t.trading_days,
      t.best_trade_pnl,
      t.worst_trade_pnl,
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
    
    FOR i IN 1..3 LOOP
      v_is_win := random() < 0.70;
      
      v_trade_pair := v_pairs[1 + floor(random() * array_length(v_pairs, 1))::integer];
      v_trade_side := v_sides[1 + floor(random() * 2)::integer];
      v_trade_leverage := floor(3 + random() * 17)::integer;
      
      IF v_is_win THEN
        v_trade_pnl := (100 + random() * 4900) * v_trader.multiplier;
      ELSE
        v_trade_pnl := -1 * (50 + random() * 1950) * v_trader.multiplier;
      END IF;
      
      v_trade_margin := ABS(v_trade_pnl) * (2 + random() * 3);
      v_trade_quantity := v_trade_margin * v_trade_leverage;
      
      v_trade_entry := CASE 
        WHEN v_trade_pair = 'BTCUSDT' THEN 95000 + random() * 10000
        WHEN v_trade_pair = 'ETHUSDT' THEN 3200 + random() * 400
        WHEN v_trade_pair = 'SOLUSDT' THEN 200 + random() * 50
        WHEN v_trade_pair = 'BNBUSDT' THEN 650 + random() * 100
        ELSE 1 + random() * 99
      END;
      
      IF v_trade_side = 'long' THEN
        v_trade_exit := v_trade_entry * (1 + (v_trade_pnl / NULLIF(v_trade_quantity, 0)));
      ELSE
        v_trade_exit := v_trade_entry * (1 - (v_trade_pnl / NULLIF(v_trade_quantity, 0)));
      END IF;
      
      INSERT INTO trader_trades (
        trader_id,
        symbol,
        side,
        entry_price,
        exit_price,
        quantity,
        margin_used,
        leverage,
        pnl,
        pnl_percent,
        status,
        opened_at,
        closed_at,
        created_at,
        updated_at
      ) VALUES (
        v_trader.id,
        v_trade_pair,
        v_trade_side,
        ROUND(v_trade_entry, 2),
        ROUND(COALESCE(v_trade_exit, v_trade_entry), 2),
        ROUND(v_trade_quantity, 2),
        ROUND(v_trade_margin, 2),
        v_trade_leverage,
        ROUND(v_trade_pnl, 2),
        ROUND((v_trade_pnl / NULLIF(v_trade_margin, 0)) * 100, 2),
        'closed',
        NOW() - (random() * INTERVAL '48 hours'),
        NOW() - (random() * INTERVAL '2 hours'),
        NOW(),
        NOW()
      );
      
      v_trades_created := v_trades_created + 1;
    END LOOP;
    
    SELECT 
      COUNT(*),
      COUNT(*) FILTER (WHERE pnl > 0),
      COALESCE(MAX(pnl), 0),
      COALESCE(MIN(pnl), 0),
      COALESCE(AVG(leverage), 10),
      COALESCE(SUM(ABS(quantity)), 0),
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
    
    WITH recent_trades AS (
      SELECT pnl > 0 as is_win,
             ROW_NUMBER() OVER (ORDER BY closed_at DESC) as rn
      FROM trader_trades
      WHERE trader_id = v_trader.id
        AND status = 'closed'
        AND closed_at IS NOT NULL
    ),
    first_loss AS (
      SELECT MIN(rn) as first_loss_rn
      FROM recent_trades
      WHERE NOT is_win
    )
    SELECT COALESCE(
      (SELECT first_loss_rn - 1 FROM first_loss WHERE first_loss_rn > 1),
      (SELECT COUNT(*) FROM recent_trades WHERE is_win)
    ) INTO v_current_streak;
    
    IF v_current_streak IS NULL OR v_current_streak < 0 THEN
      v_current_streak := floor(1 + random() * 7)::integer;
    END IF;
    
    v_max_streak := GREATEST(
      COALESCE(v_trader.max_win_streak, 10),
      v_current_streak,
      floor(8 + random() * 17)::integer
    );
    
    v_trading_days := GREATEST(30, COALESCE(v_trader.trading_days, 32));
    v_profitable_days := GREATEST(
      floor(v_trading_days * (v_winning_trades::numeric / GREATEST(v_total_trades, 1)))::integer,
      floor(v_trading_days * 0.55)::integer
    );
    
    v_roi_variance := (random() - 0.5) * 0.30;
    v_aum_variance := (random() - 0.5) * 0.10;
    v_mdd_variance := (random() - 0.5) * 0.30;
    v_sharpe_variance := (random() - 0.5) * 0.40;
    v_follower_variance := (random() - 0.5) * 0.06;
    
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
    v_new_volatility := GREATEST(5, LEAST(30, COALESCE(v_trader.volatility_score, 15) + (random() * 6 - 3)));
    v_new_consistency := GREATEST(50, LEAST(95, COALESCE(v_trader.consistency_score, 70) + (random() * 10 - 5)));
    v_monthly_return := v_new_roi / 30 * (1 + (random() * 0.4 - 0.2));
    
    UPDATE traders
    SET
      total_trades = v_total_trades,
      win_rate = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100, 1) ELSE 50 END,
      avg_win_rate_7d = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100 + (random() * 10 - 5), 1) ELSE 50 END,
      avg_win_rate_30d = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100 + (random() * 6 - 3), 1) ELSE 50 END,
      win_rate_all_time = CASE WHEN v_total_trades > 0 THEN ROUND((v_winning_trades::numeric / v_total_trades) * 100, 1) ELSE 50 END,
      win_streak = v_current_streak,
      max_win_streak = v_max_streak,
      profitable_days = v_profitable_days,
      trading_days = v_trading_days,
      best_trade_pnl = ROUND(v_best_trade, 2),
      worst_trade_pnl = ROUND(v_worst_trade, 2),
      avg_leverage = ROUND(v_avg_leverage, 1),
      total_volume = ROUND(v_total_volume, 2),
      
      roi_7d = ROUND(v_new_roi / 4.3, 2),
      roi_30d = ROUND(v_new_roi, 2),
      roi_90d = ROUND(v_new_roi * 3, 2),
      roi_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_roi * 6 ELSE v_new_roi * 2 END, 2),
      pnl_7d = ROUND(v_new_pnl / 4.3, 2),
      pnl_30d = ROUND(v_new_pnl, 2),
      pnl_90d = ROUND(v_new_pnl * 3, 2),
      pnl_all_time = ROUND(CASE WHEN v_new_roi > 0 THEN v_new_pnl * 6 ELSE v_new_pnl * 2 END, 2),
      
      aum = ROUND(v_new_aum, 2),
      mdd_30d = ROUND(v_new_mdd, 2),
      sharpe_ratio = ROUND(v_new_sharpe, 2),
      volatility_score = ROUND(v_new_volatility, 1),
      consistency_score = ROUND(v_new_consistency, 1),
      monthly_return = ROUND(v_monthly_return, 2),
      
      followers_count = v_new_followers,
      
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