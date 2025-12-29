/*
  # Increase SatoshiFan ROI by 3x

  1. Changes
    - Update SatoshiFan's target_monthly_roi from current value to 3x
    - Ensure trader is marked as automated so target ROI is used
    - Recalculate metrics to reflect new target ROI

  2. Current Value
    - SatoshiFan current ROI: 19.87%
    - New ROI (3x): 59.61%

  3. Purpose
    - Improve SatoshiFan's performance metrics
    - Make this trader more attractive to followers
*/

-- Update SatoshiFan's target ROI to 3x the current value
UPDATE traders
SET
  target_monthly_roi = 59.61,
  is_automated = true,
  updated_at = NOW()
WHERE LOWER(name) LIKE '%satoshi%fan%'
   OR name = 'SatoshiFan';

-- Recalculate metrics for SatoshiFan to apply new target ROI
DO $$
DECLARE
  v_trader_id uuid;
  v_result boolean;
BEGIN
  -- Get SatoshiFan's ID
  SELECT id INTO v_trader_id
  FROM traders
  WHERE LOWER(name) LIKE '%satoshi%fan%'
     OR name = 'SatoshiFan'
  LIMIT 1;

  -- Recalculate metrics if trader found
  IF v_trader_id IS NOT NULL THEN
    SELECT calculate_trader_metrics(v_trader_id) INTO v_result;

    IF v_result THEN
      RAISE NOTICE 'Successfully updated SatoshiFan ROI to 59.61%% and recalculated metrics';
    ELSE
      RAISE NOTICE 'Failed to recalculate metrics for SatoshiFan';
    END IF;
  ELSE
    RAISE NOTICE 'SatoshiFan trader not found';
  END IF;
END $$;

-- Verify the update
DO $$
DECLARE
  v_trader RECORD;
BEGIN
  SELECT name, target_monthly_roi, is_automated, roi_30d, pnl_30d
  INTO v_trader
  FROM traders
  WHERE LOWER(name) LIKE '%satoshi%fan%'
     OR name = 'SatoshiFan'
  LIMIT 1;

  IF v_trader.name IS NOT NULL THEN
    RAISE NOTICE '=== SatoshiFan ROI Update Summary ===';
    RAISE NOTICE 'Trader: %', v_trader.name;
    RAISE NOTICE 'Target Monthly ROI: %', v_trader.target_monthly_roi;
    RAISE NOTICE 'Is Automated: %', v_trader.is_automated;
    RAISE NOTICE 'Current ROI 30D: %', v_trader.roi_30d;
    RAISE NOTICE 'Current PNL 30D: %', v_trader.pnl_30d;
    RAISE NOTICE '====================================';
  END IF;
END $$;
