/*
  # Fix transfer_between_wallets format specifiers

  1. Problem
    - PostgreSQL format() doesn't support C-style %.2f specifiers
    - Causes "unrecognized format() type specifier" error

  2. Solution
    - Use round() with %s specifier instead
    - All numeric values properly formatted
*/

CREATE OR REPLACE FUNCTION transfer_between_wallets(
  user_id_param uuid,
  from_wallet_type_param text,
  to_wallet_type_param text,
  currency_param text,
  amount_param numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_balance numeric;
  v_from_locked numeric;
  v_allocated_to_traders numeric := 0;
  v_actual_available numeric;
  v_futures_available numeric;
BEGIN
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  IF (from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures') AND currency_param != 'USDT' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Futures wallet only supports USDT');
  END IF;

  -- ============================================
  -- CASE 1: FROM FUTURES WALLET
  -- ============================================
  IF from_wallet_type_param = 'futures' THEN
    SELECT available_balance INTO v_futures_available
    FROM futures_margin_wallets
    WHERE user_id = user_id_param
    FOR UPDATE;

    IF v_futures_available IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet not found');
    END IF;

    IF v_futures_available < amount_param THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', format('Insufficient futures balance. Available: %s USDT', round(v_futures_available, 2))
      );
    END IF;

    UPDATE futures_margin_wallets
    SET available_balance = available_balance - amount_param,
        total_withdrawn = total_withdrawn + amount_param,
        updated_at = now()
    WHERE user_id = user_id_param;

    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
    VALUES (user_id_param, 'USDT', to_wallet_type_param, amount_param, 0, now(), now())
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET
      balance = wallets.balance + amount_param,
      updated_at = now();

    INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
    VALUES (user_id_param, 'transfer', 'USDT', amount_param, 0, 'completed', now());

    RETURN jsonb_build_object(
      'success', true,
      'message', format('Transferred %s USDT from Futures to %s wallet', round(amount_param, 2), 
        CASE to_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END)
    );
  END IF;

  -- ============================================
  -- CASE 2: TO FUTURES WALLET (from main or copy)
  -- ============================================
  IF to_wallet_type_param = 'futures' THEN
    SELECT balance, COALESCE(locked_balance, 0)
    INTO v_from_balance, v_from_locked
    FROM wallets
    WHERE user_id = user_id_param
      AND currency = 'USDT'
      AND wallet_type = from_wallet_type_param
    FOR UPDATE;

    IF v_from_balance IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
    END IF;

    v_actual_available := v_from_balance - v_from_locked;

    -- For copy wallet, lock FULL relationship values (initial + profits)
    IF from_wallet_type_param = 'copy' THEN
      SELECT COALESCE(SUM(
        COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
      ), 0)
      INTO v_allocated_to_traders
      FROM copy_relationships
      WHERE follower_id = user_id_param
        AND is_active = true
        AND is_mock = false;

      v_actual_available := v_actual_available - v_allocated_to_traders;
    END IF;

    v_actual_available := GREATEST(v_actual_available, 0);

    IF amount_param > v_actual_available THEN
      IF from_wallet_type_param = 'copy' AND v_allocated_to_traders > 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', format('Insufficient balance. %s USDT is allocated to active traders. Stop copying to withdraw.', round(v_allocated_to_traders, 2))
        );
      ELSE
        RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %s USDT', round(v_actual_available, 2)));
      END IF;
    END IF;

    UPDATE wallets
    SET balance = balance - amount_param,
        updated_at = now()
    WHERE user_id = user_id_param
      AND currency = 'USDT'
      AND wallet_type = from_wallet_type_param;

    INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance, total_deposited, total_withdrawn, created_at, updated_at)
    VALUES (user_id_param, amount_param, 0, amount_param, 0, now(), now())
    ON CONFLICT (user_id) DO UPDATE
    SET available_balance = futures_margin_wallets.available_balance + amount_param,
        total_deposited = futures_margin_wallets.total_deposited + amount_param,
        updated_at = now();

    INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
    VALUES (user_id_param, 'transfer', 'USDT', amount_param, 0, 'completed', now());

    RETURN jsonb_build_object(
      'success', true,
      'message', format('Transferred %s USDT from %s to Futures wallet', round(amount_param, 2),
        CASE from_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END)
    );
  END IF;

  -- ============================================
  -- CASE 3: MAIN <-> COPY (no futures involved)
  -- ============================================
  SELECT balance, COALESCE(locked_balance, 0)
  INTO v_from_balance, v_from_locked
  FROM wallets
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param
  FOR UPDATE;

  IF v_from_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
  END IF;

  v_actual_available := v_from_balance - v_from_locked;

  -- For copy wallet source, lock FULL relationship values
  IF from_wallet_type_param = 'copy' AND currency_param = 'USDT' THEN
    SELECT COALESCE(SUM(
      COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
    ), 0)
    INTO v_allocated_to_traders
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND is_mock = false;

    v_actual_available := v_actual_available - v_allocated_to_traders;
  END IF;

  v_actual_available := GREATEST(v_actual_available, 0);

  IF amount_param > v_actual_available THEN
    IF from_wallet_type_param = 'copy' AND v_allocated_to_traders > 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format('Insufficient balance. %s USDT is allocated to active traders. Stop copying to withdraw.', round(v_allocated_to_traders, 2))
      );
    ELSE
      RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %s %s', round(v_actual_available, 2), currency_param));
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
    updated_at = now();

  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
  VALUES (user_id_param, 'transfer', currency_param, amount_param, 0, 'completed', now());

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Transferred %s %s from %s to %s wallet', round(amount_param, 4), currency_param,
      CASE from_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END,
      CASE to_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END)
  );
END;
$$;
