/*
  # Update Transactions Table - Allow All Transaction Types

  ## Description
  This migration updates the transactions table CHECK constraint to allow
  all existing transaction types plus the new 'transfer' type.

  ## Changes
  - Updates CHECK constraint to allow: deposit, withdrawal, transfer, reward, fee_rebate
  - Updates transfer functions to use correct column name 'transaction_type'
*/

-- Update transactions table to allow all transaction types
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
  CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer', 'reward', 'fee_rebate'));

-- Drop and recreate transfer functions with correct column names
DROP FUNCTION IF EXISTS transfer_to_futures_wallet(uuid, numeric);
DROP FUNCTION IF EXISTS transfer_from_futures_wallet(uuid, numeric);

-- Transfer funds TO futures wallet
CREATE OR REPLACE FUNCTION transfer_to_futures_wallet(
  p_user_id uuid,
  p_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_main_balance numeric;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount must be greater than 0'
    );
  END IF;

  -- Check main wallet balance
  SELECT balance INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT'
  FOR UPDATE;

  IF v_main_balance IS NULL OR v_main_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Available: %s USDT', COALESCE(v_main_balance, 0))
    );
  END IF;

  -- Deduct from main wallet
  UPDATE wallets
  SET balance = balance - p_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = 'USDT';

  -- Add to futures wallet
  INSERT INTO futures_margin_wallets (user_id, available_balance, total_deposited)
  VALUES (p_user_id, p_amount, p_amount)
  ON CONFLICT (user_id) DO UPDATE
  SET available_balance = futures_margin_wallets.available_balance + p_amount,
      total_deposited = futures_margin_wallets.total_deposited + p_amount,
      updated_at = now();

  -- Record transaction
  INSERT INTO transactions (
    user_id, transaction_type, amount, currency, status
  )
  VALUES (
    p_user_id, 'transfer', p_amount, 'USDT', 'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'amount', p_amount,
    'message', format('Successfully transferred %s USDT to Futures Wallet', p_amount)
  );
END;
$$ LANGUAGE plpgsql;

-- Transfer funds FROM futures wallet
CREATE OR REPLACE FUNCTION transfer_from_futures_wallet(
  p_user_id uuid,
  p_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_available_balance numeric;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount must be greater than 0'
    );
  END IF;

  -- Check futures wallet balance
  SELECT available_balance INTO v_available_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_available_balance IS NULL OR v_available_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient available balance. Available: %s USDT', COALESCE(v_available_balance, 0))
    );
  END IF;

  -- Deduct from futures wallet
  UPDATE futures_margin_wallets
  SET available_balance = available_balance - p_amount,
      total_withdrawn = total_withdrawn + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id;

  -- Add to main wallet
  UPDATE wallets
  SET balance = balance + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = 'USDT';

  -- Record transaction
  INSERT INTO transactions (
    user_id, transaction_type, amount, currency, status
  )
  VALUES (
    p_user_id, 'transfer', p_amount, 'USDT', 'completed'
  );

  RETURN jsonb_build_object(
    'success', true,
    'amount', p_amount,
    'message', format('Successfully transferred %s USDT to Main Wallet', p_amount)
  );
END;
$$ LANGUAGE plpgsql;