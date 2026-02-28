/*
  # Create Daily Metrics Recalculation Function

  1. Function Overview
    - `recalculate_all_active_trader_metrics()` - Recalculates metrics for all active traders
    
  2. Purpose
    - Ensures rolling time windows update correctly even when no trades occur
    - Provides daily refresh of all trader performance data
    - Maintains accurate 7D, 30D, 90D rolling windows
    
  3. Logic
    - Selects all traders where is_featured = true (active/public traders)
    - Loops through and calls calculate_trader_metrics() for each
    - Logs execution details and any errors
    - Returns JSON with success count and execution time
    
  4. Usage
    - Called by scheduled edge function (recalculate-trader-metrics)
    - Runs daily at 00:00 UTC
    - Can also be called manually by admins if needed
    
  5. Performance
    - Processes traders sequentially to avoid overload
    - Uses PERFORM for async execution
    - Returns detailed results for monitoring
*/

CREATE OR REPLACE FUNCTION recalculate_all_active_trader_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_success_count integer := 0;
  v_error_count integer := 0;
  v_start_time timestamptz;
  v_end_time timestamptz;
  v_duration interval;
  v_result boolean;
BEGIN
  v_start_time := NOW();
  
  -- Loop through all featured/active traders
  FOR v_trader IN
    SELECT id, name
    FROM traders
    WHERE is_featured = true
    ORDER BY id
  LOOP
    BEGIN
      -- Recalculate metrics for this trader
      SELECT calculate_trader_metrics(v_trader.id) INTO v_result;
      
      IF v_result THEN
        v_success_count := v_success_count + 1;
      ELSE
        v_error_count := v_error_count + 1;
        RAISE NOTICE 'Failed to recalculate metrics for trader: % (id: %)', v_trader.name, v_trader.id;
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      RAISE NOTICE 'Error recalculating metrics for trader % (id: %): %', v_trader.name, v_trader.id, SQLERRM;
    END;
  END LOOP;
  
  v_end_time := NOW();
  v_duration := v_end_time - v_start_time;
  
  -- Return summary
  RETURN jsonb_build_object(
    'success', true,
    'traders_processed', v_success_count,
    'errors', v_error_count,
    'start_time', v_start_time,
    'end_time', v_end_time,
    'duration_seconds', EXTRACT(EPOCH FROM v_duration),
    'message', format('Successfully recalculated metrics for %s traders with %s errors', v_success_count, v_error_count)
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'message', 'Failed to complete daily metric recalculation'
  );
END;
$$;

-- Grant execute permission to authenticated users and service role
GRANT EXECUTE ON FUNCTION recalculate_all_active_trader_metrics TO authenticated;
GRANT EXECUTE ON FUNCTION recalculate_all_active_trader_metrics TO service_role;

-- Add comment for documentation
COMMENT ON FUNCTION recalculate_all_active_trader_metrics IS 'Recalculates performance metrics for all active traders. Intended to run daily via scheduled edge function.';
