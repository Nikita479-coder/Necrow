/*
  # Fix Trader Metrics with Realistic Wide Performance Ranges

  1. Performance Ranges
    - 7 Day ROI: 3-30% (realistic weekly variation)
    - 30 Day ROI: 15-85% (monthly performance range)
    - 90 Day ROI: Calculated from 30D (2-3x monthly)
    - All Time ROI: 10-600% (long-term accumulated returns)
    
  2. Special Handling
    - Satoshi Academy gets top-tier stats (70-85% monthly, 500-600% all-time)
    - Other traders distributed across the full range
    - Ensures realistic performance hierarchy
    
  3. Calculation Logic
    - 30D is the baseline, generated first
    - 7D is 20-40% of 30D value (weekly volatility)
    - 90D is 2-3x the 30D (quarterly compounding)
    - All-time is 6-12x the 30D
    - PNL calculated from ROI and starting capital
    
  4. Purpose
    - Show realistic and varied trader performance
    - Make Satoshi Academy the flagship top performer
    - Provide meaningful differentiation between traders
*/

-- Update traders with realistic wide performance ranges
DO $$
DECLARE
  v_trader RECORD;
  v_roi_30d numeric;
  v_roi_7d numeric;
  v_roi_90d numeric;
  v_roi_alltime numeric;
  v_pnl_7d numeric;
  v_pnl_30d numeric;
  v_pnl_90d numeric;
  v_pnl_alltime numeric;
  v_7d_multiplier numeric;
  v_90d_multiplier numeric;
  v_alltime_multiplier numeric;
  v_is_satoshi boolean;
BEGIN
  RAISE NOTICE 'Updating trader metrics with realistic wide performance ranges...';
  
  FOR v_trader IN
    SELECT id, name, starting_capital, protected_trader
    FROM traders
    WHERE is_featured = true
    ORDER BY id
  LOOP
    -- Check if this is Satoshi Academy
    v_is_satoshi := (LOWER(v_trader.name) LIKE '%satoshi%');
    
    -- Generate 30D ROI based on trader type
    IF v_is_satoshi THEN
      -- Satoshi Academy: Top tier performance (70-85%)
      v_roi_30d := 70 + (random() * 15);
    ELSIF v_trader.protected_trader THEN
      -- Other protected traders: Upper tier (50-75%)
      v_roi_30d := 50 + (random() * 25);
    ELSE
      -- Regular traders: Full range (15-85%)
      v_roi_30d := 15 + (random() * 70);
    END IF;
    
    -- Calculate 7D ROI (20-40% of monthly, capped between 3-30%)
    v_7d_multiplier := 0.20 + (random() * 0.20);
    v_roi_7d := v_roi_30d * v_7d_multiplier;
    
    -- Ensure 7D stays in 3-30% range
    IF v_roi_7d < 3 THEN
      v_roi_7d := 3 + (random() * 5);
    ELSIF v_roi_7d > 30 THEN
      v_roi_7d := 25 + (random() * 5);
    END IF;
    
    -- Calculate 90D ROI (2-3x monthly)
    v_90d_multiplier := 2.0 + (random() * 1.0);
    v_roi_90d := v_roi_30d * v_90d_multiplier;
    
    -- Calculate All-Time ROI
    IF v_is_satoshi THEN
      -- Satoshi Academy: 500-600%
      v_roi_alltime := 500 + (random() * 100);
    ELSIF v_trader.protected_trader THEN
      -- Protected traders: Upper range (300-500%)
      v_roi_alltime := 300 + (random() * 200);
    ELSE
      -- Regular traders: Full range (10-600%)
      -- Higher 30D performers likely have higher all-time
      IF v_roi_30d > 60 THEN
        v_roi_alltime := 250 + (random() * 350);  -- 250-600%
      ELSIF v_roi_30d > 40 THEN
        v_roi_alltime := 100 + (random() * 300);  -- 100-400%
      ELSE
        v_roi_alltime := 10 + (random() * 200);   -- 10-210%
      END IF;
    END IF;
    
    -- Calculate PNL from ROI and starting capital
    v_pnl_7d := (v_trader.starting_capital * v_roi_7d / 100);
    v_pnl_30d := (v_trader.starting_capital * v_roi_30d / 100);
    v_pnl_90d := (v_trader.starting_capital * v_roi_90d / 100);
    v_pnl_alltime := (v_trader.starting_capital * v_roi_alltime / 100);
    
    -- Update the trader with calculated metrics
    UPDATE traders
    SET
      roi_7d = ROUND(v_roi_7d, 2),
      pnl_7d = ROUND(v_pnl_7d, 2),
      roi_30d = ROUND(v_roi_30d, 2),
      pnl_30d = ROUND(v_pnl_30d, 2),
      roi_90d = ROUND(v_roi_90d, 2),
      pnl_90d = ROUND(v_pnl_90d, 2),
      roi_all_time = ROUND(v_roi_alltime, 2),
      pnl_all_time = ROUND(v_pnl_alltime, 2),
      metrics_last_updated = NOW(),
      updated_at = NOW()
    WHERE id = v_trader.id;
    
  END LOOP;
  
  RAISE NOTICE 'Completed updating all trader metrics with wide performance ranges';
END $$;

-- Verify the metrics and show Satoshi Academy at the top
DO $$
DECLARE
  v_sample RECORD;
BEGIN
  RAISE NOTICE '=== Top Trader Performance Verification ===';
  
  FOR v_sample IN
    SELECT 
      name,
      ROUND(roi_7d, 2) as roi_7d,
      ROUND(roi_30d, 2) as roi_30d,
      ROUND(roi_90d, 2) as roi_90d,
      ROUND(roi_all_time, 2) as roi_all_time
    FROM traders
    WHERE is_featured = true
    ORDER BY roi_all_time DESC
    LIMIT 10
  LOOP
    RAISE NOTICE 'Trader: %', v_sample.name;
  END LOOP;
  
  RAISE NOTICE '==========================================';
END $$;
