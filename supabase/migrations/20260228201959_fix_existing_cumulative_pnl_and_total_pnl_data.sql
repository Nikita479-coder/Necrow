/*
  # Correct existing cumulative_pnl and total_pnl data

  1. Problem
    - Due to the double-counting bug (both close_trader_trade and trigger updating cumulative_pnl),
      many copy_relationships have inflated cumulative_pnl and total_pnl values

  2. Fix
    - Recalculate cumulative_pnl and total_pnl from the actual sum of realized_pnl
      in closed copy_trade_allocations for each relationship
    - This gives the correct single-counted PNL value

  3. Impact
    - All copy_relationships will have accurate PNL tracking
    - Withdrawal calculations will use correct values going forward
*/

UPDATE copy_relationships cr
SET
  cumulative_pnl = COALESCE(correct.total_realized_pnl, 0),
  total_pnl = COALESCE(correct.total_realized_pnl, 0),
  updated_at = NOW()
FROM (
  SELECT
    cta.copy_relationship_id,
    SUM(COALESCE(cta.realized_pnl, 0)) AS total_realized_pnl
  FROM copy_trade_allocations cta
  WHERE cta.status = 'closed'
  GROUP BY cta.copy_relationship_id
) correct
WHERE cr.id = correct.copy_relationship_id
AND (
  cr.cumulative_pnl IS DISTINCT FROM COALESCE(correct.total_realized_pnl, 0)
  OR cr.total_pnl IS DISTINCT FROM COALESCE(correct.total_realized_pnl, 0)
);
