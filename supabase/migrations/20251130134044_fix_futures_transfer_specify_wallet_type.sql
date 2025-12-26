/*
  # Fix Futures Transfer Functions to Specify Main Wallet Type

  ## Summary
  The transfer_to_futures_wallet and transfer_from_futures_wallet functions
  were not specifying wallet_type='main', causing them to query any wallet
  with the currency. This resulted in incorrect balance checks and transfers.

  ## Changes
  1. Update transfer_to_futures_wallet to explicitly use wallet_type='main'
  2. Update transfer_from_futures_wallet to explicitly use wallet_type='main'
  3. Update get_wallet_balances to explicitly use wallet_type='main'

  ## Impact
  - Transfers now correctly use the main wallet
  - Balance checks are accurate
  - Funds no longer disappear when transferring to/from futures
*/

-- Transfer funds TO futures wallet (fixed version)
CREATE OR REPLACE FUNCTION transfer_to_futures_wallet(
  p_user_id uuid,
  p_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_main_balance numeric;
  v_main_locked numeric;
  v_available numeric;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount must be greater than 0'
    );
  END IF;

  -- Check main wallet balance (excluding locked balance)
  SELECT balance, locked_balance INTO v_main_balance, v_main_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main'
  FOR UPDATE;

  v_available := COALESCE(v_main_balance, 0) - COALESCE(v_main_locked, 0);

  IF v_main_balance IS NULL OR v_available < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Available: %s USDT', v_available),
      'debug_balance', v_available,
      'debug_requested', p_amount
    );
  END IF;

  -- Deduct from main wallet
  UPDATE wallets
  SET balance = balance - p_amount,
      updated_at = now()
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

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
$$;

-- Transfer funds FROM futures wallet (fixed version)
CREATE OR REPLACE FUNCTION transfer_from_futures_wallet(
  p_user_id uuid,
  p_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- If main wallet doesn't exist, create it
  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'main', p_amount);
  END IF;

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
$$;

-- Get wallet balances (fixed version)
CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_main_balance numeric;
  v_futures_available numeric;
  v_futures_locked numeric;
BEGIN
  -- Get main wallet balance
  SELECT balance INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- Get futures wallet balances
  SELECT available_balance, locked_balance 
  INTO v_futures_available, v_futures_locked
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'main_wallet', COALESCE(v_main_balance, 0),
    'futures_available', COALESCE(v_futures_available, 0),
    'futures_locked', COALESCE(v_futures_locked, 0),
    'futures_total', COALESCE(v_futures_available, 0) + COALESCE(v_futures_locked, 0)
  );
END;
$$;