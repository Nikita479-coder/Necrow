/*
  # Fix Copy Trading Withdrawal - Complete Flow

  ## Problem
  1. PostgreSQL format() function doesn't support %.2f format specifiers
  2. The frontend sets is_active=false but status stays 'active', so the transfer
     function still counts the balance as allocated

  ## Solution
  1. Fix all format() calls to use string concatenation with ROUND()
  2. Make the transfer function properly handle copy wallet withdrawals when
     a relationship is in the process of stopping (is_active=false but status='active')
  3. Or alternatively, skip the allocated check when is_active is already false
*/

DROP FUNCTION IF EXISTS transfer_between_wallets(uuid, text, numeric, text, text);

CREATE FUNCTION transfer_between_wallets(
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
  v_from_balance numeric;
  v_from_locked numeric := 0;
  v_actual_available numeric;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric;
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

  IF currency_param != 'USDT' AND (from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures') THEN
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
        'error', 'Insufficient futures balance. Available: ' || ROUND(v_futures_available, 2)::text || ' USDT'
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
      'message', 'Transferred ' || ROUND(amount_param, 2)::text || ' USDT from Futures to ' || 
        CASE to_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END || ' wallet'
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

    -- For copy wallet, subtract allocated funds (ONLY for truly active relationships)
    -- Check BOTH is_active AND status to ensure relationship is truly active
    IF from_wallet_type_param = 'copy' THEN
      SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
      INTO v_allocated_to_traders
      FROM copy_relationships
      WHERE follower_id = user_id_param
        AND is_active = true
        AND status = 'active'
        AND is_mock = false;

      v_actual_available := v_actual_available - v_allocated_to_traders;
    END IF;

    IF v_actual_available < amount_param THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'Insufficient balance. ' || ROUND(v_allocated_to_traders, 2)::text || ' USDT is allocated to active traders. Stop copying to withdraw.'
      );
    END IF;

    UPDATE wallets
    SET balance = balance - amount_param,
        updated_at = now()
    WHERE user_id = user_id_param
      AND currency = 'USDT'
      AND wallet_type = from_wallet_type_param;

    INSERT INTO futures_margin_wallets (user_id, available_balance, margin_balance, total_deposited, total_withdrawn, created_at, updated_at)
    VALUES (user_id_param, amount_param, 0, amount_param, 0, now(), now())
    ON CONFLICT (user_id)
    DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + amount_param,
      total_deposited = futures_margin_wallets.total_deposited + amount_param,
      updated_at = now();

    INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
    VALUES (user_id_param, 'transfer', 'USDT', amount_param, 0, 'completed', now());

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Transferred ' || ROUND(amount_param, 2)::text || ' USDT to Futures wallet'
    );
  END IF;

  -- ============================================
  -- CASE 3: BETWEEN MAIN AND COPY WALLETS
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

  -- For copy wallet, subtract allocated funds (ONLY for truly active relationships)
  -- Check BOTH is_active AND status to ensure relationship is truly active
  IF from_wallet_type_param = 'copy' THEN
    SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
    INTO v_allocated_to_traders
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND status = 'active'
      AND is_mock = false;

    v_actual_available := v_actual_available - v_allocated_to_traders;
  END IF;

  IF v_actual_available < amount_param THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Insufficient balance. ' || ROUND(v_allocated_to_traders, 2)::text || ' USDT is allocated to active traders. Stop copying to withdraw.'
    );
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
    'message', 'Transferred ' || ROUND(amount_param, 2)::text || ' ' || currency_param || ' from ' || 
      from_wallet_type_param || ' to ' || to_wallet_type_param || ' wallet'
  );
END;
$$;