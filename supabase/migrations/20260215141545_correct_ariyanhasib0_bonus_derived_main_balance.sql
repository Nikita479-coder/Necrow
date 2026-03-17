/*
  # Correct ariyanhasib0 main wallet balance (bonus fund leak)

  1. Issue
    - User ariyanhasib0@gmail.com (51776eb9-bab6-4141-92ef-cd9c93f5c746) transferred
      locked bonus funds from futures wallet to main wallet
    - The transfer_between_wallets function had no protection against this
    - All funds in futures wallet originated from locked bonuses (First Deposit Bonus + backfill)
    - Every futures position was 100% bonus-funded (margin_from_locked_bonus = margin_allocated)
    - The 18.86 USDT in main wallet is entirely bonus-derived and must be removed

  2. Changes
    - Sets main USDT wallet balance to 0 for this user
    - Logs a corrective transaction for audit trail

  3. Notes
    - User's copy trading balance (111 USDT from 100 USDT deposit) is unaffected
    - Withdrawal was already rejected so no external funds were lost
    - The transfer_between_wallets function has been fixed in a separate migration
*/

UPDATE wallets
SET balance = 0,
    updated_at = now()
WHERE user_id = '51776eb9-bab6-4141-92ef-cd9c93f5c746'
  AND wallet_type = 'main'
  AND currency = 'USDT'
  AND balance > 0;

INSERT INTO transactions (
  user_id,
  transaction_type,
  amount,
  currency,
  status,
  details,
  admin_notes
) VALUES (
  '51776eb9-bab6-4141-92ef-cd9c93f5c746',
  'adjustment',
  18.86066967,
  'USDT',
  'completed',
  'Balance correction: bonus-derived funds removed from main wallet',
  'Locked bonus funds were transferred from futures to main wallet due to missing transfer protection. All futures activity was 100% bonus-funded. Corrective action applied.'
);
