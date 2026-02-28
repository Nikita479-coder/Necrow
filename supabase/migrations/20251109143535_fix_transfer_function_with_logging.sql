/*
  # Fix Transfer Function with Better Debugging

  ## Description
  This migration updates the transfer function to provide better error
  messages and handle edge cases like missing wallet records.

  ## Changes
  - Adds automatic wallet creation if missing
  - Provides detailed error messages
  - Handles all edge cases properly
*/

-- Drop and recreate transfer function with better error handling
DROP FUNCTION IF EXISTS transfer_to_futures_wallet(uuid, numeric);

CREATE OR REPLACE FUNCTION transfer_to_futures_wallet(
  p_user_id uuid,
  p_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_main_balance numeric;
  v_wallet_exists boolean;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount must be greater than 0'
    );
  END IF;

  -- Check if wallet exists
  SELECT EXISTS(
    SELECT 1 FROM wallets 
    WHERE user_id = p_user_id AND currency = 'USDT'
  ) INTO v_wallet_exists;

  -- If wallet doesn't exist, create it
  IF NOT v_wallet_exists THEN
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited)
    VALUES (p_user_id, 'USDT', 10000, 0, 10000)
    ON CONFLICT (user_id, currency) DO NOTHING;
  END IF;

  -- Get main wallet balance with lock
  SELECT balance INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT'
  FOR UPDATE;

  -- Check if we have enough balance
  IF v_main_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Wallet not found. Please contact support.',
      'debug_user_id', p_user_id::text
    );
  END IF;

  IF v_main_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Available: %s USDT', v_main_balance),
      'debug_balance', v_main_balance,
      'debug_requested', p_amount
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
    'new_main_balance', v_main_balance - p_amount,
    'message', format('Successfully transferred %s USDT to Futures Wallet', p_amount)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;