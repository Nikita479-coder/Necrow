/*
  # Fix Copy Wallet Transfer - Allocated Funds Already Deducted

  ## Problem
  The transfer_between_wallets function was preventing transfers by checking
  allocated funds in copy_relationships. However, when trades are accepted,
  funds are already DEDUCTED from the copy wallet. The allocated amount is
  NOT in the wallet - it's been taken out and is with traders.

  ## Solution
  Remove the allocated balance check for copy wallet transfers since:
  1. When user accepts a trade, funds are deducted from copy wallet
  2. The allocated amount is tracked in copy_trade_allocations
  3. The copy_relationships.current_balance represents funds with traders (not in wallet)
  4. User can only transfer what's actually IN the wallet balance

  ## Changes
  - Removed the allocated balance calculation and check
  - Copy wallet transfers now work like other wallet types
  - Simply check wallet balance against transfer amount
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

  -- Handle futures wallet transfers separately
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

  -- Get source wallet balance
  SELECT balance INTO from_wallet_balance
  FROM wallets
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF from_wallet_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  -- Check if sufficient balance (works for all wallet types including copy)
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

  -- Add to destination wallet
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (user_id_param, currency_param, to_wallet_type_param, amount_param, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + amount_param,
    updated_at = now()
  RETURNING id INTO to_wallet_id;

  -- Log transaction
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
