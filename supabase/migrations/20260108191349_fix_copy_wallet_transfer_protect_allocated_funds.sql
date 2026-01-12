/*
  # Fix Copy Wallet Transfer - Protect Allocated Funds

  ## Problem
  Users can transfer their entire copy wallet balance even when funds are
  allocated to active copy trading relationships. The allocated funds should
  not be transferable.

  ## Solution
  When transferring from copy wallet:
  1. Calculate total allocated to active traders (current_balance from copy_relationships)
  2. Subtract allocated amount from available balance
  3. Only allow transfer up to the unallocated amount

  ## Changes
  - Added allocated balance check for copy wallet transfers
  - Protects funds committed to active copy trading relationships
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
  from_wallet_locked numeric;
  allocated_to_traders numeric := 0;
  actual_available numeric;
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
  SELECT balance, COALESCE(locked_balance, 0)
  INTO from_wallet_balance, from_wallet_locked
  FROM wallets
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF from_wallet_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  -- Calculate actual available balance
  actual_available := from_wallet_balance - from_wallet_locked;

  -- For copy wallet, also subtract funds allocated to active traders
  IF from_wallet_type_param = 'copy' AND currency_param = 'USDT' THEN
    SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
    INTO allocated_to_traders
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND is_mock = false;

    -- Reduce available by allocated amount
    actual_available := actual_available - allocated_to_traders;
  END IF;

  -- Ensure non-negative
  actual_available := GREATEST(actual_available, 0);

  -- Check if sufficient balance
  IF amount_param > actual_available THEN
    IF from_wallet_type_param = 'copy' AND allocated_to_traders > 0 THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', format('Insufficient balance. %.2f USDT is allocated to active traders.', allocated_to_traders)
      );
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
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
