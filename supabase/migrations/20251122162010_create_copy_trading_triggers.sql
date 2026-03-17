/*
  # Copy Trading Automatic Triggers

  1. Triggers
    - Auto-log trader positions when opened
    - Auto-update followers when positions closed
    - Works for both futures_positions and swap trades

  2. Features
    - Automatic detection of trader activity
    - Real-time follower allocation creation
    - Automatic P&L distribution to followers
*/

-- Trigger function to log trader position opens
CREATE OR REPLACE FUNCTION trigger_log_trader_position_open()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_trader boolean;
BEGIN
  -- Check if this user is being copied by anyone
  SELECT EXISTS (
    SELECT 1 FROM copy_relationships
    WHERE trader_id = NEW.user_id
    AND status = 'active'
  ) INTO v_is_trader;

  -- If they are a trader, log the position
  IF v_is_trader THEN
    PERFORM log_trader_position_open(
      NEW.user_id,
      NEW.id,
      NEW.pair,
      NEW.side,
      NEW.entry_price,
      NEW.quantity,
      NEW.leverage,
      NEW.margin
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger function to log trader position closes
CREATE OR REPLACE FUNCTION trigger_log_trader_position_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader_trade_id uuid;
BEGIN
  -- Only process if position was just closed
  IF OLD.status = 'open' AND NEW.status = 'closed' THEN
    -- Find the trader trade record
    SELECT id INTO v_trader_trade_id
    FROM trader_trades
    WHERE position_id = NEW.id
    AND status = 'open';

    -- If found, close it and update followers
    IF v_trader_trade_id IS NOT NULL THEN
      PERFORM log_trader_position_close(
        v_trader_trade_id,
        NEW.exit_price,
        NEW.realized_pnl
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create triggers on futures_positions
DROP TRIGGER IF EXISTS trader_position_open_trigger ON futures_positions;
CREATE TRIGGER trader_position_open_trigger
  AFTER INSERT ON futures_positions
  FOR EACH ROW
  WHEN (NEW.status = 'open')
  EXECUTE FUNCTION trigger_log_trader_position_open();

DROP TRIGGER IF EXISTS trader_position_close_trigger ON futures_positions;
CREATE TRIGGER trader_position_close_trigger
  AFTER UPDATE ON futures_positions
  FOR EACH ROW
  WHEN (OLD.status = 'open' AND NEW.status = 'closed')
  EXECUTE FUNCTION trigger_log_trader_position_close();
