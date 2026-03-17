/*
  # Recalculate all cumulative_pnl and total_pnl from actual allocation data

  ## Problem
  - 161 out of 387 copy_relationships have incorrect cumulative_pnl and total_pnl
  - Caused by the close_trader_trade function double-counting PNL alongside the trigger
  - The function bug has been fixed in the previous migration

  ## Fix
  - Recalculate both cumulative_pnl and total_pnl from the sum of realized_pnl
    in closed copy_trade_allocations for every relationship
  - Relationships with no closed allocations get reset to 0

  ## Impact
  - All 387 copy_relationships will have correct PNL values
  - Users will see accurate Total PNL and ROI on their copy trading dashboard
*/

UPDATE copy_relationships cr
SET
  cumulative_pnl = correct.actual_pnl,
  total_pnl = correct.actual_pnl,
  updated_at = NOW()
FROM (
  SELECT
    cr2.id,
    COALESCE(SUM(cta.realized_pnl), 0) as actual_pnl
  FROM copy_relationships cr2
  LEFT JOIN copy_trade_allocations cta 
    ON cta.copy_relationship_id = cr2.id 
    AND cta.status = 'closed'
  GROUP BY cr2.id
) correct
WHERE cr.id = correct.id
AND (
  cr.cumulative_pnl IS DISTINCT FROM correct.actual_pnl
  OR cr.total_pnl IS DISTINCT FROM correct.actual_pnl
);
