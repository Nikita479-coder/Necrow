/*
  # Create Automatic Metric Recalculation Trigger

  1. Trigger Function
    - `trigger_recalculate_trader_metrics_on_trade_close()` - Automatically recalculates trader metrics when a trade closes
    
  2. Trigger Logic
    - Fires AFTER INSERT or UPDATE on trader_trades table
    - Only executes when status = 'closed' AND closed_at IS NOT NULL
    - Calls calculate_trader_metrics() for the affected trader_id
    - Uses PERFORM for async execution without blocking
    
  3. Purpose
    - Ensures trader metrics are always up-to-date when trades close
    - Eliminates need for manual metric updates
    - Provides real-time performance data for public trader profiles
    
  4. Performance
    - Only triggers on trade close (not on every trade update)
    - Efficient queries with indexed columns (trader_id, closed_at, status)
    - Async execution prevents blocking trade operations
*/

-- Create trigger function
CREATE OR REPLACE FUNCTION trigger_recalculate_trader_metrics_on_trade_close()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only recalculate if the trade is closed
  IF NEW.status = 'closed' AND NEW.closed_at IS NOT NULL THEN
    -- Perform metric recalculation (async, non-blocking)
    PERFORM calculate_trader_metrics(NEW.trader_id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS trg_recalculate_metrics_on_trade_close ON trader_trades;

-- Create trigger on trader_trades table
CREATE TRIGGER trg_recalculate_metrics_on_trade_close
  AFTER INSERT OR UPDATE ON trader_trades
  FOR EACH ROW
  WHEN (NEW.status = 'closed' AND NEW.closed_at IS NOT NULL)
  EXECUTE FUNCTION trigger_recalculate_trader_metrics_on_trade_close();

-- Add comment for documentation
COMMENT ON FUNCTION trigger_recalculate_trader_metrics_on_trade_close IS 'Trigger function that automatically recalculates trader metrics when a trade closes';
COMMENT ON TRIGGER trg_recalculate_metrics_on_trade_close ON trader_trades IS 'Automatically recalculates trader metrics when a trade is closed';
