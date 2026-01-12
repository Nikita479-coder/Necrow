/*
  # Add comprehensive trader statistics

  1. Schema Changes
    - Add detailed performance metrics to traders table
    - Add 7-day and 90-day performance data
    - Add trading style and risk metrics
    - Add monthly and all-time statistics

  2. New Columns
    - roi_7d, roi_90d, roi_all_time
    - pnl_7d, pnl_90d, pnl_all_time
    - win_streak, loss_streak, max_win_streak
    - profitable_days, trading_days
    - avg_win_rate_7d, avg_win_rate_90d
    - best_trade_pnl, worst_trade_pnl
    - volatility_score, consistency_score
    - trading_style (scalper, swing, position)
    - risk_level (low, medium, high)
*/

-- Add new columns to traders table
ALTER TABLE traders ADD COLUMN IF NOT EXISTS roi_7d numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS roi_90d numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS roi_all_time numeric DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS pnl_7d numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS pnl_90d numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS pnl_all_time numeric DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS win_streak int DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS loss_streak int DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS max_win_streak int DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS profitable_days int DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS trading_days int DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS avg_win_rate_7d numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS avg_win_rate_90d numeric DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS best_trade_pnl numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS worst_trade_pnl numeric DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS volatility_score numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS consistency_score numeric DEFAULT 0;

ALTER TABLE traders ADD COLUMN IF NOT EXISTS trading_style text DEFAULT 'swing';
ALTER TABLE traders ADD COLUMN IF NOT EXISTS risk_level text DEFAULT 'medium';

ALTER TABLE traders ADD COLUMN IF NOT EXISTS avg_leverage numeric DEFAULT 5;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS favorite_pairs text[] DEFAULT ARRAY['BTCUSDT', 'ETHUSDT'];

ALTER TABLE traders ADD COLUMN IF NOT EXISTS monthly_return numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS total_volume numeric DEFAULT 0;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS avg_hold_time_hours numeric DEFAULT 24;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS win_rate numeric DEFAULT 60;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS total_trades int DEFAULT 100;

-- Update all traders with realistic random statistics
DO $$
DECLARE
  v_trader record;
  v_roi_30d numeric;
  v_base_volatility numeric;
  v_style text;
  v_risk text;
  v_hold_time numeric;
  v_win_rate numeric;
  v_total_trades int;
BEGIN
  FOR v_trader IN SELECT * FROM traders LOOP
    v_roi_30d := v_trader.roi_30d;
    v_hold_time := (2 + random() * 120);
    v_win_rate := CASE
      WHEN v_roi_30d > 50 THEN (65 + random() * 15)
      WHEN v_roi_30d > 30 THEN (60 + random() * 10)
      WHEN v_roi_30d > 10 THEN (55 + random() * 10)
      ELSE (45 + random() * 15)
    END;
    v_total_trades := (50 + (random() * 200)::int);

    -- Determine trading style based on random hold time
    IF v_hold_time < 4 THEN
      v_style := 'scalper';
      v_base_volatility := 15 + random() * 10;
    ELSIF v_hold_time < 24 THEN
      v_style := 'day_trader';
      v_base_volatility := 10 + random() * 8;
    ELSIF v_hold_time < 168 THEN
      v_style := 'swing';
      v_base_volatility := 8 + random() * 6;
    ELSE
      v_style := 'position';
      v_base_volatility := 5 + random() * 4;
    END IF;

    -- Determine risk level based on ROI and volatility
    IF v_roi_30d > 50 AND v_base_volatility > 15 THEN
      v_risk := 'high';
    ELSIF v_roi_30d < 20 AND v_base_volatility < 10 THEN
      v_risk := 'low';
    ELSE
      v_risk := 'medium';
    END IF;

    UPDATE traders SET
      -- Base stats
      win_rate = v_win_rate,
      total_trades = v_total_trades,

      -- 7-day stats (more volatile, similar trend to 30d)
      roi_7d = v_roi_30d * (0.15 + random() * 0.25),
      pnl_7d = v_trader.pnl_30d * (0.15 + random() * 0.25),
      avg_win_rate_7d = v_win_rate * (0.85 + random() * 0.30),

      -- 90-day stats (more stable, larger numbers)
      roi_90d = v_roi_30d * (2.5 + random() * 1.0),
      pnl_90d = v_trader.pnl_30d * (2.5 + random() * 1.0),
      avg_win_rate_90d = v_win_rate * (0.95 + random() * 0.10),

      -- All-time stats (even larger)
      roi_all_time = v_roi_30d * (8 + random() * 4),
      pnl_all_time = v_trader.pnl_30d * (8 + random() * 4),

      -- Win/Loss streaks
      win_streak = CASE
        WHEN v_roi_30d > 0 THEN (2 + (random() * 6)::int)
        ELSE 0
      END,
      loss_streak = CASE
        WHEN v_roi_30d < 0 THEN (1 + (random() * 3)::int)
        ELSE 0
      END,
      max_win_streak = (5 + (random() * 15)::int),

      -- Trading days
      profitable_days = (45 + (random() * 40)::int),
      trading_days = (80 + (random() * 40)::int),

      -- Best and worst trades
      best_trade_pnl = (500 + random() * 4500),
      worst_trade_pnl = -(100 + random() * 800),

      -- Performance scores (0-100)
      volatility_score = v_base_volatility,
      consistency_score = CASE
        WHEN v_win_rate > 70 THEN (75 + random() * 20)
        WHEN v_win_rate > 60 THEN (60 + random() * 20)
        WHEN v_win_rate > 50 THEN (45 + random() * 20)
        ELSE (30 + random() * 20)
      END,

      -- Trading style and risk
      trading_style = v_style,
      risk_level = v_risk,

      -- Average leverage (higher for high-risk traders)
      avg_leverage = CASE
        WHEN v_risk = 'high' THEN (8 + random() * 12)
        WHEN v_risk = 'medium' THEN (3 + random() * 7)
        ELSE (1 + random() * 4)
      END,

      -- Favorite trading pairs (3-5 pairs)
      favorite_pairs = CASE (random() * 5)::int
        WHEN 0 THEN ARRAY['BTCUSDT', 'ETHUSDT', 'BNBUSDT']
        WHEN 1 THEN ARRAY['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'AVAXUSDT']
        WHEN 2 THEN ARRAY['ETHUSDT', 'LINKUSDT', 'ADAUSDT', 'DOTUSDT']
        WHEN 3 THEN ARRAY['BTCUSDT', 'MATICUSDT', 'XRPUSDT']
        WHEN 4 THEN ARRAY['SOLUSDT', 'AVAXUSDT', 'NEARUSDT', 'ATOMUSDT']
        ELSE ARRAY['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'ADAUSDT', 'DOGEUSDT']
      END,

      -- Monthly return (roughly 30d ROI adjusted)
      monthly_return = v_roi_30d * (0.9 + random() * 0.2),

      -- Total volume traded
      total_volume = (v_trader.aum * (20 + random() * 80)),

      -- Avg hold time
      avg_hold_time_hours = v_hold_time

    WHERE id = v_trader.id;
  END LOOP;
END $$;
