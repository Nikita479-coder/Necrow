/*
  # Fix stale bonus_amount on stopped and forfeited relationships

  ## Problem
  When copy trading relationships are stopped or bonuses are forfeited, the
  bonus_amount field on copy_relationships is not reset to 0. This causes
  incorrect profit-sharing fee calculations if the relationship is restarted,
  because original_allocation = initial_balance - bonus_amount treats user
  capital as profit.

  ## Changes
  1. Reset bonus_amount to 0 on all stopped relationships (bonus already settled)
  2. Reset bonus_amount to 0 on active relationships where the bonus was forfeited
     (bonus no longer in play, should not affect fee calculations)
  3. Reset bonus_locked_until to NULL on all affected relationships

  ## Impact
  - Prevents future fee overcharges when stopped relationships are restarted
  - Fixes one active relationship with forfeited bonus that would be overcharged
*/

UPDATE copy_relationships
SET bonus_amount = 0, bonus_locked_until = NULL, updated_at = now()
WHERE status = 'stopped'
AND bonus_amount > 0;

UPDATE copy_relationships cr
SET bonus_amount = 0, bonus_locked_until = NULL, updated_at = now()
WHERE cr.is_active = true
AND cr.bonus_amount > 0
AND EXISTS (
  SELECT 1 FROM copy_trading_bonus_claims ctbc
  WHERE ctbc.relationship_id = cr.id
  AND ctbc.forfeited = true
);
