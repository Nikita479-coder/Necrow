/*
  # Fix All Doubled Cumulative PNL Values

  ## Problem
  - Many copy relationships have cumulative_pnl that is 2x what it should be
  - This happened because both the trigger and close_trader_trade function were updating it
  - The close_trader_trade function has been fixed, but we need to fix existing data

  ## Solution
  - Recalculate cumulative_pnl for all active copy relationships
  - Set it to the actual sum of closed allocations
  - Also fix total_pnl to match

  ## Impact
  - All active copy relationships will show correct PNL values
  - Frontend will display accurate ROI and balance information
*/

-- Fix all copy relationships where cumulative_pnl doesn't match actual allocations
WITH correct_pnl AS (
  SELECT 
    cr.id as relationship_id,
    COALESCE(SUM(cta.realized_pnl), 0) as correct_cumulative_pnl
  FROM copy_relationships cr
  LEFT JOIN copy_trade_allocations cta ON cta.copy_relationship_id = cr.id 
    AND cta.status = 'closed'
  WHERE cr.is_active = true
  GROUP BY cr.id
)
UPDATE copy_relationships cr
SET 
  cumulative_pnl = cp.correct_cumulative_pnl,
  total_pnl = cp.correct_cumulative_pnl,
  updated_at = NOW()
FROM correct_pnl cp
WHERE cr.id = cp.relationship_id
  AND ABS(cr.cumulative_pnl - cp.correct_cumulative_pnl) > 0.01;
