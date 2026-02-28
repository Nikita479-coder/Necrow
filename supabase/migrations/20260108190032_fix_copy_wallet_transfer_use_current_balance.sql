/*
  # Fix Copy Wallet Transfer to Use Current Balance

  ## Problem
  The transfer_between_wallets function was checking allocated funds using
  initial_balance, but should use current_balance which includes profits/losses
  from copy trading. This allowed users to withdraw profits that were actually
  still allocated to active traders.

  ## Solution
  Update the transfer_between_wallets function to:
  1. Sum current_balance instead of initial_balance from copy_relationships
  2. Fall back to initial_balance if current_balance is null or zero
  3. Provide accurate error message showing actual allocated amount

  ## Changes
  - Modified transfer_between_wallets to use COALESCE(current_balance, initial_balance)
  - This ensures profits/losses are included in the allocated amount
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
  allocated_to_traders numeric := 0;
  available_for_transfer numeric;
BEGIN
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  IF from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures' THEN
    IF currency_param != 'USDT' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet only supports USDT');
    END IF;

    IF from_wallet_type_param = 'futures' THEN
      RETURN transfer_from_futures_wallet(user_id_param, amount_param);
    END IF;

    IF to_wallet_type_param = 'futures' THEN
      RETURN transfer_to_futures_wallet(user_id_param, amount_param);
    END IF;
  END IF;

  SELECT balance INTO from_wallet_balance
  FROM wallets
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF from_wallet_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  -- For copy wallet, calculate allocated funds using current_balance (includes profits/losses)
  IF from_wallet_type_param = 'copy' AND currency_param = 'USDT' THEN
    SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance)), 0) INTO allocated_to_traders
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND is_mock = false;

    available_for_transfer := from_wallet_balance - allocated_to_traders;

    IF amount_param > available_for_transfer THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format(
          'Insufficient available balance. %.2f USDT is allocated to active copy trading (including profits/losses).',
          allocated_to_traders
        )
      );
    END IF;
  ELSE
    IF from_wallet_balance < amount_param THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
  END IF;

  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param;

  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (user_id_param, currency_param, to_wallet_type_param, amount_param, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + amount_param,
    updated_at = now()
  RETURNING id INTO to_wallet_id;

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
