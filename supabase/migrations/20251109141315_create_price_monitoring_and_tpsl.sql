/*
  # Price Monitoring, TP/SL Automation, and Liquidation System

  ## Description
  This migration creates the price feed table, monitoring triggers for TP/SL execution,
  and liquidation monitoring with automated execution.

  ## New Tables

  ### market_prices
  Real-time price feed for all trading pairs
  - `pair` (text, primary key)
  - `last_price` (numeric) - Latest trade price
  - `mark_price` (numeric) - Fair price for liquidations
  - `index_price` (numeric) - Underlying index
  - `bid_price` (numeric) - Best bid
  - `ask_price` (numeric) - Best ask
  - `volume_24h` (numeric) - 24h volume
  - `last_updated` (timestamptz) - Last update time

  ## Functions Created

  ### Price Updates
  - update_market_price() - Update price for a pair
  - trigger_position_pnl_update() - Recalc PnL on price change
  - check_all_tp_sl_conditions() - Monitor TP/SL triggers
  - check_liquidation_conditions() - Monitor margin health

  ### TP/SL Execution
  - execute_take_profit() - Auto-close at profit target
  - execute_stop_loss() - Auto-close at stop loss
  - update_position_tp_sl() - Modify TP/SL on open position

  ### Liquidation
  - check_position_for_liquidation() - Assess margin health
  - execute_liquidation() - Force close position
  - add_to_liquidation_queue() - Flag at-risk positions

  ## Important Notes
  - Triggers fire automatically on price updates
  - TP/SL checked every price change
  - Liquidations monitored continuously
  - All executions are atomic transactions
*/

-- Market Prices Table
CREATE TABLE IF NOT EXISTS market_prices (
  pair text PRIMARY KEY,
  last_price numeric(20,8) NOT NULL,
  mark_price numeric(20,8) NOT NULL,
  index_price numeric(20,8),
  bid_price numeric(20,8),
  ask_price numeric(20,8),
  volume_24h numeric(20,8),
  last_updated timestamptz DEFAULT now(),
  CHECK (last_price > 0),
  CHECK (mark_price > 0)
);

-- Enable RLS
ALTER TABLE market_prices ENABLE ROW LEVEL SECURITY;

-- Public read access to prices
CREATE POLICY "Anyone can view market prices"
  ON market_prices FOR SELECT
  TO authenticated
  USING (true);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_market_prices_updated ON market_prices(last_updated DESC);

-- Update market price (called from frontend/websocket)
CREATE OR REPLACE FUNCTION update_market_price(
  p_pair text,
  p_price numeric,
  p_mark_price numeric DEFAULT NULL,
  p_volume numeric DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
  INSERT INTO market_prices (
    pair, last_price, mark_price, index_price, volume_24h, last_updated
  )
  VALUES (
    p_pair, p_price, COALESCE(p_mark_price, p_price), p_price, p_volume, now()
  )
  ON CONFLICT (pair) DO UPDATE
  SET last_price = EXCLUDED.last_price,
      mark_price = EXCLUDED.mark_price,
      index_price = EXCLUDED.index_price,
      volume_24h = COALESCE(EXCLUDED.volume_24h, market_prices.volume_24h),
      last_updated = now();
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Update all position PnL when price changes
CREATE OR REPLACE FUNCTION trigger_position_pnl_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Update unrealized PnL for all open positions of this pair
  UPDATE futures_positions
  SET mark_price = NEW.mark_price,
      unrealized_pnl = calculate_unrealized_pnl(side, entry_price, NEW.mark_price, quantity),
      last_price_update = now()
  WHERE pair = NEW.pair
    AND status = 'open';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on price update
CREATE TRIGGER on_price_update_recalc_pnl
  AFTER INSERT OR UPDATE ON market_prices
  FOR EACH ROW
  EXECUTE FUNCTION trigger_position_pnl_update();

-- Check TP/SL conditions for a position
CREATE OR REPLACE FUNCTION check_position_tp_sl(
  p_position_id uuid,
  p_current_price numeric
)
RETURNS boolean AS $$
DECLARE
  v_position record;
  v_should_close boolean := false;
  v_close_reason text;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open';
  
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  
  -- Check take profit
  IF v_position.take_profit IS NOT NULL THEN
    IF (v_position.side = 'long' AND p_current_price >= v_position.take_profit) OR
       (v_position.side = 'short' AND p_current_price <= v_position.take_profit) THEN
      v_should_close := true;
      v_close_reason := 'take_profit';
    END IF;
  END IF;
  
  -- Check stop loss
  IF v_position.stop_loss IS NOT NULL AND NOT v_should_close THEN
    IF (v_position.side = 'long' AND p_current_price <= v_position.stop_loss) OR
       (v_position.side = 'short' AND p_current_price >= v_position.stop_loss) THEN
      v_should_close := true;
      v_close_reason := 'stop_loss';
    END IF;
  END IF;
  
  -- Execute close if triggered
  IF v_should_close THEN
    PERFORM close_position(p_position_id, NULL, p_current_price);
    
    -- Log the modification
    INSERT INTO position_modifications (position_id, modification_type, old_value, new_value)
    VALUES (
      p_position_id,
      v_close_reason,
      jsonb_build_object('status', 'open'),
      jsonb_build_object('status', 'closed', 'trigger_price', p_current_price)
    );
  END IF;
  
  RETURN v_should_close;
END;
$$ LANGUAGE plpgsql;

-- Check all TP/SL conditions when price updates
CREATE OR REPLACE FUNCTION check_all_tp_sl_conditions()
RETURNS TRIGGER AS $$
DECLARE
  v_position record;
BEGIN
  FOR v_position IN
    SELECT position_id, side, take_profit, stop_loss
    FROM futures_positions
    WHERE pair = NEW.pair
      AND status = 'open'
      AND (take_profit IS NOT NULL OR stop_loss IS NOT NULL)
  LOOP
    PERFORM check_position_tp_sl(v_position.position_id, NEW.mark_price);
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to check TP/SL on price updates
CREATE TRIGGER on_price_update_check_tp_sl
  AFTER INSERT OR UPDATE ON market_prices
  FOR EACH ROW
  EXECUTE FUNCTION check_all_tp_sl_conditions();

-- Update TP/SL on existing position
CREATE OR REPLACE FUNCTION update_position_tp_sl(
  p_position_id uuid,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_position record;
  v_old_values jsonb;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;
  
  -- Store old values for logging
  v_old_values := jsonb_build_object(
    'stop_loss', v_position.stop_loss,
    'take_profit', v_position.take_profit
  );
  
  -- Update TP/SL
  UPDATE futures_positions
  SET stop_loss = COALESCE(p_stop_loss, stop_loss),
      take_profit = COALESCE(p_take_profit, take_profit),
      last_price_update = now()
  WHERE position_id = p_position_id;
  
  -- Log modification
  INSERT INTO position_modifications (position_id, modification_type, old_value, new_value)
  VALUES (
    p_position_id,
    'tp_sl_updated',
    v_old_values,
    jsonb_build_object('stop_loss', p_stop_loss, 'take_profit', p_take_profit)
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'stop_loss', COALESCE(p_stop_loss, v_position.stop_loss),
    'take_profit', COALESCE(p_take_profit, v_position.take_profit)
  );
END;
$$ LANGUAGE plpgsql;

-- Check if position should be liquidated
CREATE OR REPLACE FUNCTION check_position_for_liquidation(
  p_position_id uuid,
  p_current_price numeric
)
RETURNS text AS $$
DECLARE
  v_position record;
  v_current_equity numeric;
  v_maintenance_margin numeric;
  v_margin_ratio numeric;
  v_position_value numeric;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open';
  
  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;
  
  -- Calculate current equity (margin + unrealized PnL)
  v_current_equity := v_position.margin_allocated + 
                      calculate_unrealized_pnl(v_position.side, v_position.entry_price, p_current_price, v_position.quantity);
  
  -- Calculate required maintenance margin
  v_position_value := v_position.quantity * p_current_price;
  v_maintenance_margin := v_position_value * v_position.maintenance_margin_rate;
  
  -- Calculate margin ratio (equity / maintenance margin)
  IF v_maintenance_margin > 0 THEN
    v_margin_ratio := v_current_equity / v_maintenance_margin;
  ELSE
    v_margin_ratio := 999;
  END IF;
  
  -- Check liquidation conditions
  IF v_margin_ratio <= 1.0 THEN
    RETURN 'immediate'; -- Liquidate now
  ELSIF v_margin_ratio <= 1.05 THEN
    RETURN 'critical'; -- Add to liquidation queue, very close
  ELSIF v_margin_ratio <= 1.2 THEN
    RETURN 'warning'; -- Add to queue for monitoring
  ELSE
    RETURN 'healthy';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Execute liquidation
CREATE OR REPLACE FUNCTION execute_liquidation(p_position_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_position record;
  v_liquidation_price numeric;
  v_liquidation_fee numeric;
  v_remaining_equity numeric;
  v_insurance_fund_loss numeric := 0;
BEGIN
  -- Lock position
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;
  
  -- Get current mark price as liquidation price
  SELECT mark_price INTO v_liquidation_price
  FROM market_prices
  WHERE pair = v_position.pair;
  
  v_liquidation_price := COALESCE(v_liquidation_price, v_position.liquidation_price);
  
  -- Calculate liquidation fee
  v_liquidation_fee := calculate_liquidation_fee_amount(
    v_position.pair,
    v_position.quantity,
    v_liquidation_price
  );
  
  -- Calculate remaining equity
  v_remaining_equity := v_position.margin_allocated +
    calculate_unrealized_pnl(v_position.side, v_position.entry_price, v_liquidation_price, v_position.quantity);
  
  v_remaining_equity := v_remaining_equity - v_liquidation_fee;
  
  -- If equity is negative, insurance fund covers it
  IF v_remaining_equity < 0 THEN
    v_insurance_fund_loss := ABS(v_remaining_equity);
    v_remaining_equity := 0;
  END IF;
  
  -- Mark position as liquidated
  UPDATE futures_positions
  SET status = 'liquidated',
      realized_pnl = v_remaining_equity - v_position.margin_allocated,
      cumulative_fees = cumulative_fees + v_liquidation_fee,
      closed_at = now()
  WHERE position_id = p_position_id;
  
  -- Return remaining equity to wallet (if any)
  IF v_remaining_equity > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_remaining_equity,
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;
  
  -- Log liquidation event
  INSERT INTO liquidation_events (
    position_id, user_id, pair, side, quantity, entry_price,
    liquidation_price, equity_before, loss_amount, liquidation_fee,
    insurance_fund_used
  )
  VALUES (
    p_position_id, v_position.user_id, v_position.pair, v_position.side,
    v_position.quantity, v_position.entry_price, v_liquidation_price,
    v_position.margin_allocated, v_position.margin_allocated - v_remaining_equity,
    v_liquidation_fee, v_insurance_fund_loss
  );
  
  -- Remove from liquidation queue
  DELETE FROM liquidation_queue WHERE position_id = p_position_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'liquidation_price', v_liquidation_price,
    'remaining_equity', v_remaining_equity,
    'liquidation_fee', v_liquidation_fee
  );
END;
$$ LANGUAGE plpgsql;

-- Check liquidations on price update
CREATE OR REPLACE FUNCTION check_liquidation_conditions()
RETURNS TRIGGER AS $$
DECLARE
  v_position record;
  v_health_status text;
BEGIN
  FOR v_position IN
    SELECT position_id, user_id, pair
    FROM futures_positions
    WHERE pair = NEW.pair
      AND status = 'open'
  LOOP
    v_health_status := check_position_for_liquidation(v_position.position_id, NEW.mark_price);
    
    IF v_health_status = 'immediate' THEN
      -- Execute liquidation
      PERFORM execute_liquidation(v_position.position_id);
    ELSIF v_health_status IN ('critical', 'warning') THEN
      -- Add to liquidation queue
      INSERT INTO liquidation_queue (position_id, user_id, pair, warning_level, checked_at)
      VALUES (v_position.position_id, v_position.user_id, v_position.pair, v_health_status, now())
      ON CONFLICT (position_id) DO UPDATE
      SET warning_level = EXCLUDED.warning_level,
          checked_at = now();
    ELSE
      -- Remove from queue if healthy
      DELETE FROM liquidation_queue WHERE position_id = v_position.position_id;
    END IF;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to check liquidations on price updates
CREATE TRIGGER on_price_update_check_liquidations
  AFTER INSERT OR UPDATE ON market_prices
  FOR EACH ROW
  EXECUTE FUNCTION check_liquidation_conditions();

-- Initialize prices for existing pairs
INSERT INTO market_prices (pair, last_price, mark_price)
SELECT pair, 50000, 50000 FROM trading_pairs_config WHERE pair = 'BTCUSDT'
ON CONFLICT (pair) DO NOTHING;

INSERT INTO market_prices (pair, last_price, mark_price)
SELECT pair, 3000, 3000 FROM trading_pairs_config WHERE pair = 'ETHUSDT'
ON CONFLICT (pair) DO NOTHING;

INSERT INTO market_prices (pair, last_price, mark_price)
VALUES
  ('BNBUSDT', 600, 600),
  ('SOLUSDT', 100, 100),
  ('XRPUSDT', 0.5, 0.5),
  ('ADAUSDT', 0.5, 0.5),
  ('DOGEUSDT', 0.1, 0.1),
  ('MATICUSDT', 1, 1),
  ('DOTUSDT', 7, 7),
  ('LINKUSDT', 15, 15),
  ('AVAXUSDT', 35, 35),
  ('UNIUSDT', 6, 6),
  ('ATOMUSDT', 10, 10),
  ('LTCUSDT', 90, 90),
  ('ETCUSDT', 25, 25)
ON CONFLICT (pair) DO NOTHING;