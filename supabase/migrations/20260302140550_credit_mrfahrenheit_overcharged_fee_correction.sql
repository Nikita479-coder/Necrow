/*
  # Credit mrfahrenheitwork@gmail.com for overcharged copy trading fee

  ## Problem
  User was overcharged on copy trading withdrawal due to bonus profit calculation bug.
  
  - Bonus amount: $100 (not forfeited, lock period passed)
  - Profit was calculated as $256.07 (against $400 original_allocation)
  - Should have been $156.07 (against $500 initial_balance including bonus)
  - Fee charged: $51.21 (20% of $256.07)
  - Correct fee: $31.21 (20% of $156.07)
  - Overcharge: $20.00

  ## Fix
  Credit $20 to the user's main USDT wallet
*/

DO $$
DECLARE
  v_user_id uuid := '1565226d-b56a-4393-bc8d-d4cea46ced32';
  v_correction_amount numeric := 20.00;
BEGIN
  UPDATE wallets
  SET balance = balance + v_correction_amount,
      updated_at = now()
  WHERE user_id = v_user_id
  AND currency = 'USDT'
  AND wallet_type = 'main';

  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, details, admin_notes, confirmed_at)
  VALUES (
    v_user_id,
    'admin_credit',
    'USDT',
    v_correction_amount,
    0,
    'completed',
    'Balance correction - fee calculation adjustment',
    'Fee correction - Copy trading withdrawal overcharge. Bonus of $100 was incorrectly treated as profit, causing 20% fee on it ($20 extra).',
    now()
  );

  INSERT INTO notifications (user_id, type, title, message, read, created_at)
  VALUES (
    v_user_id,
    'system',
    'Balance Correction',
    'A correction of 20.00 USDT has been applied to your account for a fee calculation error on your recent copy trading withdrawal.',
    false,
    now()
  );
END $$;
