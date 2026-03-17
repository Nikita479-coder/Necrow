/*
  # Initialize Trader Metrics System

  1. Data Initialization
    - Set starting_capital to 10,000,000 for all existing traders
    - Mark "Satoshi Academy" or similar special traders as protected_trader
    - Run initial metric calculations for all traders based on existing trade history
    
  2. Protected Traders
    - Satoshi Academy (or traders with "Satoshi" in name)
    - These traders will never show negative performance metrics
    - Ensures premium brand image for flagship traders
    
  3. Initial Calculation
    - Calculates all metrics based on existing trader_trades data
    - Sets metrics_last_updated timestamp
    - Ensures all traders have accurate baseline metrics
    
  4. Purpose
    - Bootstrap the dynamic metrics system with existing data
    - Identify and protect flagship traders
    - Ensure smooth transition from static to dynamic metrics
*/

-- Set starting_capital for all existing traders
UPDATE traders
SET starting_capital = 10000000
WHERE starting_capital IS NULL OR starting_capital = 0;

-- Mark protected traders (Satoshi Academy and similar flagship traders)
UPDATE traders
SET protected_trader = true
WHERE LOWER(name) LIKE '%satoshi%'
   OR LOWER(name) LIKE '%academy%';

-- Log which traders were marked as protected
DO $$
DECLARE
  v_protected_traders text;
BEGIN
  SELECT string_agg(name, ', ') INTO v_protected_traders
  FROM traders
  WHERE protected_trader = true;
  
  IF v_protected_traders IS NOT NULL THEN
    RAISE NOTICE 'Protected traders: %', v_protected_traders;
  ELSE
    RAISE NOTICE 'No traders were marked as protected';
  END IF;
END $$;

-- Run initial metric calculations for all featured traders
DO $$
DECLARE
  v_trader RECORD;
  v_result boolean;
  v_success_count integer := 0;
  v_error_count integer := 0;
BEGIN
  RAISE NOTICE 'Starting initial metric calculations for all traders...';
  
  FOR v_trader IN
    SELECT id, name
    FROM traders
    WHERE is_featured = true
    ORDER BY id
  LOOP
    BEGIN
      SELECT calculate_trader_metrics(v_trader.id) INTO v_result;
      
      IF v_result THEN
        v_success_count := v_success_count + 1;
        RAISE NOTICE 'Calculated metrics for: % (id: %)', v_trader.name, v_trader.id;
      ELSE
        v_error_count := v_error_count + 1;
        RAISE NOTICE 'Failed to calculate metrics for: % (id: %)', v_trader.name, v_trader.id;
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      RAISE NOTICE 'Error calculating metrics for % (id: %): %', v_trader.name, v_trader.id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Initial calculation complete: % success, % errors', v_success_count, v_error_count;
END $$;

-- Verify the system is working
DO $$
DECLARE
  v_total_traders integer;
  v_calculated_traders integer;
  v_protected_traders integer;
BEGIN
  SELECT COUNT(*) INTO v_total_traders FROM traders WHERE is_featured = true;
  SELECT COUNT(*) INTO v_calculated_traders FROM traders WHERE metrics_last_updated IS NOT NULL;
  SELECT COUNT(*) INTO v_protected_traders FROM traders WHERE protected_trader = true;
  
  RAISE NOTICE '=== Trader Metrics System Initialization Summary ===';
  RAISE NOTICE 'Total featured traders: %', v_total_traders;
  RAISE NOTICE 'Traders with calculated metrics: %', v_calculated_traders;
  RAISE NOTICE 'Protected traders: %', v_protected_traders;
  RAISE NOTICE '===================================================';
END $$;
