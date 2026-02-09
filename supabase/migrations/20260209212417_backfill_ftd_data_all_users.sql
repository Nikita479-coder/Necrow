/*
  # Backfill First-Time Deposit (FTD) Data for All Users

  1. Changes
    - Scans every `user_profiles` row where `ftd_at IS NULL`
    - For each user, finds their earliest completed deposit from `crypto_deposits`
      (status in 'finished', 'partially_paid', 'overpaid')
    - Sets `ftd_at` to the deposit's `completed_at` timestamp
    - Sets `ftd_amount` to the deposit's `price_amount` (USD value)
    - Sets `ftd_deposit_id` to the deposit's `payment_id`

  2. Scope
    - Affects all 62 users with completed deposits across all affiliates
    - This is not limited to any single affiliate's referrals

  3. Why
    - The FTD columns were added for the recruitment boost system but were never
      populated by the deposit completion pipeline
    - All boost tier calculations depend on these fields being filled in
    - Without this backfill, every affiliate shows 0 qualifying FTDs

  4. Safety
    - Only updates rows where `ftd_at IS NULL` (idempotent)
    - Uses a CTE to pick the earliest deposit per user, so repeat deposits are ignored
    - No destructive operations
*/

UPDATE user_profiles up
SET
  ftd_at = first_deps.completed_at,
  ftd_amount = first_deps.price_amount,
  ftd_deposit_id = first_deps.payment_id
FROM (
  SELECT DISTINCT ON (cd.user_id)
    cd.user_id,
    cd.payment_id,
    cd.price_amount,
    cd.completed_at
  FROM crypto_deposits cd
  WHERE cd.status IN ('finished', 'partially_paid', 'overpaid')
    AND cd.completed_at IS NOT NULL
  ORDER BY cd.user_id, cd.completed_at ASC
) first_deps
WHERE up.id = first_deps.user_id
  AND up.ftd_at IS NULL;
