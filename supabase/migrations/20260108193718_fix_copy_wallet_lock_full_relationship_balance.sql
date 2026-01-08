/*
  # Fix Copy Wallet to Lock Full Relationship Balance

  ## Problem
  Currently only the amount in open positions (copy_trade_allocations) is locked.
  The user wants ALL funds allocated to traders to be locked - not just open positions.

  ## Solution
  Change the allocated amount calculation to use:
  - SUM(initial_balance + cumulative_pnl) from copy_relationships where is_active = true
  
  This locks the full value of active copy trading relationships.

  ## Example
  - User allocated 868.35 to Satoshi Academy
  - Profits: 450.01
  - Total locked: 1,318.36 (not just 239.96 in open positions)
*/

-- Update get_wallet_balances to lock full relationship value
CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_main_locked numeric := 0;
  v_copy_balance numeric := 0;
  v_copy_locked numeric := 0;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric := 0;
  v_futures_locked numeric := 0;
BEGIN
  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_main_balance, v_main_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_copy_balance, v_copy_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'copy';

  -- Lock the FULL value of active copy relationships (initial + profits)
  SELECT COALESCE(SUM(
    COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
  ), 0)
  INTO v_allocated_to_traders
  FROM copy_relationships
  WHERE follower_id = p_user_id
    AND is_active = true
    AND is_mock = false;

  SELECT COALESCE(available_balance, 0), COALESCE(locked_balance, 0)
  INTO v_futures_available, v_futures_locked
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'main_wallet', v_main_balance,
    'main_locked', v_main_locked,
    'main_available', GREATEST(v_main_balance - v_main_locked, 0),
    'copy_wallet', v_copy_balance,
    'copy_locked', v_copy_locked,
    'copy_allocated', v_allocated_to_traders,
    'copy_available', GREATEST(v_copy_balance - v_copy_locked - v_allocated_to_traders, 0),
    'futures_available', v_futures_available,
    'futures_locked', v_futures_locked,
    'futures_total', v_futures_available + v_futures_locked,
    'total_trading_available', v_futures_available
  );
END;
$$;

-- Update transfer_between_wallets to use same logic
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
        'error', format('Insufficient futures balance. Available: %.2f USDT', v_futures_available)
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
      'message', format('Transferred %.2f USDT from Futures to %s wallet', amount_param, 
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
          'error', format('Insufficient balance. %.2f USDT is allocated to active traders. Stop copying to withdraw.', v_allocated_to_traders)
        );
      ELSE
        RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %.2f USDT', v_actual_available));
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
      'message', format('Transferred %.2f USDT from %s to Futures wallet', amount_param,
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
        'error', format('Insufficient balance. %.2f USDT is allocated to active traders. Stop copying to withdraw.', v_allocated_to_traders)
      );
    ELSE
      RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %.2f %s', v_actual_available, currency_param));
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
    'message', format('Transferred %.4f %s from %s to %s wallet', amount_param, currency_param,
      CASE from_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END,
      CASE to_wallet_type_param WHEN 'main' THEN 'Main' ELSE 'Copy Trading' END)
  );
END;
$$;
