/*
  # Credit Balance Correction for garamara870@gmail.com
  
  ## Issue
  User was overcharged 33.01 USDT during copy trading withdrawal on March 6, 2026.
  
  ## Root Cause
  The stop_and_withdraw_copy_trading function incorrectly flagged 33 USDT as "previously_withdrawn"
  due to a wallet balance desynchronization. This amount was deducted from the withdrawal,
  resulting in the user receiving 281.00 USDT instead of 314.01 USDT.
  
  ## Financial Analysis
  - Initial Balance: 189.71 USDT
  - Final Balance: 345.08 USDT
  - Actual Profit: 155.37 USDT
  - Correct Platform Fee (20%): 31.07 USDT
  - Expected Withdrawal: 314.01 USDT
  - Actual Withdrawal: 281.00 USDT
  - **Overcharge: 33.01 USDT**
  
  ## Correction
  Credit 33.00 USDT to user's main wallet with proper transaction logging.
*/

DO $$
DECLARE
  v_user_id uuid := '35ddb641-c9b9-4aac-9534-b36a61deafb6';
  v_wallet_id uuid;
  v_correction_amount numeric := 33.00;
BEGIN
  -- Get user's main wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_user_id
  AND wallet_type = 'main'
  AND currency = 'USDT'
  LIMIT 1;

  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'Main USDT wallet not found for user %', v_user_id;
  END IF;

  -- Credit the correction amount to main wallet
  UPDATE wallets
  SET 
    balance = balance + v_correction_amount,
    updated_at = now()
  WHERE id = v_wallet_id;

  -- Log the transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    details,
    created_at
  ) VALUES (
    v_user_id,
    'admin_credit',
    v_correction_amount,
    'USDT',
    'completed',
    'Balance correction: Copy trading withdrawal overcharge refund (March 6, 2026). User was incorrectly charged for 33 USDT flagged as previously_withdrawn.',
    now()
  );

  -- Log admin activity
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    target_user_id,
    metadata,
    created_at
  ) VALUES (
    v_user_id, -- System correction
    'balance_adjustment',
    'Credited 33.00 USDT - Copy trading withdrawal overcharge correction',
    v_user_id,
    jsonb_build_object(
      'amount', v_correction_amount,
      'reason', 'wallet_cap_bug_correction',
      'original_withdrawal_date', '2026-03-06',
      'original_withdrawal_amount', 281.00,
      'correct_withdrawal_amount', 314.01,
      'overcharge_amount', 33.01,
      'bug_description', 'stop_and_withdraw function incorrectly flagged 33 USDT as previously_withdrawn due to wallet balance desync'
    ),
    now()
  );

  RAISE NOTICE 'Successfully credited % USDT to user % (garamara870@gmail.com)', v_correction_amount, v_user_id;
END $$;
