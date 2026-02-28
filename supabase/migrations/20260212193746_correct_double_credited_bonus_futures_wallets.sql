/*
  # Correct futures wallet balances inflated by double-credit bug

  1. Problem
    - award_locked_bonus was crediting bonus amounts to BOTH locked_bonuses AND futures_margin_wallets
    - This inflated futures wallets by the total of all locked bonuses awarded to each user
    - Users could trade with the inflated "real" balance and extract withdrawable funds

  2. Fix
    - For every user who received locked bonuses, subtract the total bonus amount
      from their futures_margin_wallets.available_balance
    - Cap at 0 to prevent negative balances
    - This removes the phantom "real" credit that should never have existed

  3. Notes
    - Users with open positions: only available_balance is corrected, locked margin is untouched
    - Users who already transferred inflated funds to main wallet may need separate admin review
    - This is conservative: it removes the original bonus credit but not any compounded profits
*/

UPDATE futures_margin_wallets fmw
SET 
  available_balance = GREATEST(fmw.available_balance - bc.total_bonus_credited, 0),
  updated_at = now()
FROM (
  SELECT user_id, SUM(original_amount) as total_bonus_credited
  FROM locked_bonuses
  GROUP BY user_id
) bc
WHERE fmw.user_id = bc.user_id
AND fmw.available_balance > 0;
