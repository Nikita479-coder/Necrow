/*
  # Fix Exclusive Affiliate Withdrawals to Main Wallet

  ## Changes
  1. **Modified Withdrawal Function**
     - Withdrawals now go directly to the user's main wallet
     - No longer requires admin approval
     - Instant transfer with transaction tracking
     - Still maintains withdrawal history for auditing

  ## Security
  - Maintains balance checks
  - Prevents negative balances
  - Proper transaction logging
  - RLS policies remain intact
*/

-- Update the withdrawal function to transfer directly to main wallet
CREATE OR REPLACE FUNCTION request_exclusive_affiliate_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_wallet_address text DEFAULT NULL,
  p_network text DEFAULT 'TRC20'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance exclusive_affiliate_balances;
  v_withdrawal_id uuid;
  v_wallet_id uuid;
BEGIN
  -- Check if user is enrolled
  IF NOT is_exclusive_affiliate(p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enrolled in exclusive affiliate program');
  END IF;

  -- Lock the balance row
  SELECT * INTO v_balance
  FROM exclusive_affiliate_balances
  WHERE user_id = p_user_id
  FOR UPDATE;

  -- Validate balance
  IF NOT FOUND OR v_balance.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Minimum withdrawal check
  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;

  -- Get or create main wallet for USDT
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, 'USDT', 0, 'main')
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Deduct from exclusive affiliate balance
  UPDATE exclusive_affiliate_balances
  SET
    available_balance = available_balance - p_amount,
    total_withdrawn = total_withdrawn + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id;

  -- Add to main wallet
  UPDATE wallets
  SET
    balance = balance + p_amount,
    updated_at = now()
  WHERE id = v_wallet_id;

  -- Create transaction record
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    p_user_id,
    'affiliate_withdrawal',
    p_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'source', 'exclusive_affiliate',
      'destination', 'main_wallet',
      'wallet_id', v_wallet_id
    )
  );

  -- Create withdrawal history record (for tracking purposes)
  INSERT INTO exclusive_affiliate_withdrawals (
    user_id,
    amount,
    currency,
    wallet_address,
    network,
    status,
    processed_at
  ) VALUES (
    p_user_id,
    p_amount,
    'USDT',
    COALESCE(p_wallet_address, 'Main Wallet Transfer'),
    p_network,
    'completed',
    now()
  )
  RETURNING id INTO v_withdrawal_id;

  -- Send notification
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    p_user_id,
    'withdrawal_approved',
    'Affiliate Earnings Transferred',
    'Your affiliate earnings of $' || p_amount || ' USDT have been transferred to your main wallet.',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount,
    'destination', 'main_wallet'
  );
END;
$$;

-- Add affiliate_withdrawal transaction type if not exists
DO $$
BEGIN
  -- Check if the type constraint exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'transactions_transaction_type_check'
  ) THEN
    -- Add the new type to the constraint
    ALTER TABLE transactions
    DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;

    ALTER TABLE transactions
    ADD CONSTRAINT transactions_transaction_type_check
    CHECK (transaction_type IN (
      'deposit', 'withdraw', 'trade', 'futures_trade', 'futures_pnl',
      'futures_funding', 'swap', 'transfer', 'bonus', 'referral_commission',
      'staking_deposit', 'staking_withdraw', 'staking_reward', 'reward',
      'fee', 'fee_rebate', 'admin_credit', 'admin_debit', 'locked_trading_bonus',
      'futures_fee', 'futures_open_fee', 'futures_close_fee',
      'affiliate_commission', 'affiliate_withdrawal'
    ));
  END IF;
END $$;
