/*
  # Fix Stale locked_balance for All Users

  1. Problem
    - Multiple users have `locked_balance` stuck at old withdrawal amounts
    - The `admin_process_withdrawal` function had a bug where it skipped
      the wallet update if `balance < amount`, leaving locked_balance stale
    - This causes users to see $0 available in their main wallet despite
      having actual balance

  2. Solution
    - Reset `locked_balance` on all main wallets to match only the sum
      of actually pending withdrawal transactions
    - Users with no pending withdrawals get locked_balance = 0
    - Users with pending withdrawals keep only the correct locked amount

  3. Security
    - No RLS changes
    - Data-only fix, no schema changes
*/

UPDATE wallets w
SET locked_balance = COALESCE(pending.total_pending, 0),
    updated_at = now()
FROM (
  SELECT w2.user_id, w2.currency,
         COALESCE(SUM(ABS(t.amount)), 0) as total_pending
  FROM wallets w2
  LEFT JOIN transactions t 
    ON t.user_id = w2.user_id 
    AND t.currency = w2.currency 
    AND t.transaction_type = 'withdrawal' 
    AND t.status = 'pending'
  WHERE w2.wallet_type = 'main'
    AND w2.locked_balance > 0
  GROUP BY w2.user_id, w2.currency
) pending
WHERE w.user_id = pending.user_id
  AND w.currency = pending.currency
  AND w.wallet_type = 'main'
  AND w.locked_balance > COALESCE(pending.total_pending, 0);
