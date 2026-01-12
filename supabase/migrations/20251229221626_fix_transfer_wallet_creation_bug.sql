/*
  # Fix transfer_between_wallets Wallet Creation Bug

  ## Problem
  When transferring to a non-existent wallet, the function creates the wallet
  with 0 balance, then tries to update it. But if there's any issue between
  these operations, funds can get stuck or lost.

  ## Solution
  Use INSERT ... ON CONFLICT with a single atomic operation to ensure
  the wallet is created with the correct balance in one step.

  ## Impact
  - Prevents funds from getting stuck during transfers
  - Ensures atomic wallet creation + balance update
*/

CREATE OR REPLACE FUNCTION transfer_between_wallets(
  user_id_param uuid,
  currency_param text,
  amount_param numeric,
  from_wallet_type_param text,
  to_wallet_type_param text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  from_wallet_balance numeric;
  to_wallet_id uuid;
BEGIN
  -- Validate inputs
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'assets', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  -- Special handling for futures wallet (only supports USDT)
  IF from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures' THEN
    IF currency_param != 'USDT' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet only supports USDT');
    END IF;

    -- Transfer FROM futures wallet
    IF from_wallet_type_param = 'futures' THEN
      RETURN transfer_from_futures_wallet(user_id_param, amount_param);
    END IF;

    -- Transfer TO futures wallet
    IF to_wallet_type_param = 'futures' THEN
      RETURN transfer_to_futures_wallet(user_id_param, amount_param);
    END IF;
  END IF;

  -- Check source wallet balance
  SELECT balance INTO from_wallet_balance
  FROM wallets
  WHERE user_id = user_id_param 
    AND currency = currency_param 
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF from_wallet_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  IF from_wallet_balance < amount_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Deduct from source wallet
  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param;

  -- Add to destination wallet (create if doesn't exist) - ATOMIC OPERATION
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (user_id_param, currency_param, to_wallet_type_param, amount_param, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET 
    balance = wallets.balance + amount_param,
    updated_at = now()
  RETURNING id INTO to_wallet_id;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status,
    confirmed_at
  ) VALUES (
    user_id_param,
    'transfer',
    currency_param,
    amount_param,
    0,
    'completed',
    now()
  );

  RETURN jsonb_build_object(
    'success', true, 
    'message', format('Successfully transferred %s %s from %s to %s', amount_param, currency_param, from_wallet_type_param, to_wallet_type_param)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION transfer_between_wallets TO authenticated;
