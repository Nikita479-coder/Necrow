/*
  # Fix Transfer Between Wallets - All Combinations

  ## Problem
  The current transfer system has several bugs:
  1. Copy <-> Futures transfers incorrectly use Main wallet
  2. The transfer_to/from_futures functions always assume Main wallet as source/target
  3. This causes funds to disappear or be incorrectly credited

  ## Solution
  1. Rewrite transfer_between_wallets to handle ALL combinations properly
  2. Create new helper functions for each wallet type combination
  3. Ensure proper wallet creation on credit side
  4. Add proper validation and error messages

  ## Wallet Types
  - main: Regular wallet (wallets table, any currency)
  - copy: Copy trading wallet (wallets table, any currency)  
  - futures: Futures margin wallet (futures_margin_wallets table, USDT only)

  ## Changes
  - Complete rewrite of transfer_between_wallets function
  - Proper handling of all 6 transfer combinations
  - Better error messages and validation
*/

-- Complete rewrite of transfer function
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
  -- Validate: Same wallet type not allowed
  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to same wallet type');
  END IF;

  -- Validate: Amount must be positive
  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
  END IF;

  -- Validate: Wallet types
  IF from_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'copy', 'futures') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  -- Validate: Futures only supports USDT
  IF (from_wallet_type_param = 'futures' OR to_wallet_type_param = 'futures') AND currency_param != 'USDT' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Futures wallet only supports USDT');
  END IF;

  -- ============================================
  -- CASE 1: FROM FUTURES WALLET
  -- ============================================
  IF from_wallet_type_param = 'futures' THEN
    -- Get futures available balance
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

    -- Deduct from futures wallet
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - amount_param,
        total_withdrawn = total_withdrawn + amount_param,
        updated_at = now()
    WHERE user_id = user_id_param;

    -- Credit to destination (main or copy)
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
    VALUES (user_id_param, 'USDT', to_wallet_type_param, amount_param, 0, now(), now())
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET
      balance = wallets.balance + amount_param,
      updated_at = now();

    -- Log transaction
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
    -- Get source wallet balance
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

    -- For copy wallet, subtract allocated funds
    IF from_wallet_type_param = 'copy' THEN
      SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
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
          'error', format('Insufficient balance. %.2f USDT is allocated to active traders.', v_allocated_to_traders)
        );
      ELSE
        RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %.2f USDT', v_actual_available));
      END IF;
    END IF;

    -- Deduct from source wallet
    UPDATE wallets
    SET balance = balance - amount_param,
        updated_at = now()
    WHERE user_id = user_id_param
      AND currency = 'USDT'
      AND wallet_type = from_wallet_type_param;

    -- Credit to futures wallet
    INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance, total_deposited, total_withdrawn, created_at, updated_at)
    VALUES (user_id_param, amount_param, 0, amount_param, 0, now(), now())
    ON CONFLICT (user_id) DO UPDATE
    SET available_balance = futures_margin_wallets.available_balance + amount_param,
        total_deposited = futures_margin_wallets.total_deposited + amount_param,
        updated_at = now();

    -- Log transaction
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
  -- Get source wallet balance
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

  -- For copy wallet source, subtract allocated funds
  IF from_wallet_type_param = 'copy' AND currency_param = 'USDT' THEN
    SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
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
        'error', format('Insufficient balance. %.2f USDT is allocated to active traders.', v_allocated_to_traders)
      );
    ELSE
      RETURN jsonb_build_object('success', false, 'error', format('Insufficient balance. Available: %.2f %s', v_actual_available, currency_param));
    END IF;
  END IF;

  -- Deduct from source wallet
  UPDATE wallets
  SET balance = balance - amount_param,
      updated_at = now()
  WHERE user_id = user_id_param
    AND currency = currency_param
    AND wallet_type = from_wallet_type_param;

  -- Credit to destination wallet
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (user_id_param, currency_param, to_wallet_type_param, amount_param, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + amount_param,
    updated_at = now();

  -- Log transaction
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

-- Also update get_wallet_balances to include copy wallet info and return total_trading_available
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
  v_copy_allocated numeric := 0;
  v_futures_available numeric := 0;
  v_futures_locked numeric := 0;
BEGIN
  -- Get main wallet balance
  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_main_balance, v_main_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- Get copy wallet balance
  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_copy_balance, v_copy_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'copy';

  -- Get allocated to traders from copy wallet
  SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0)
  INTO v_copy_allocated
  FROM copy_relationships
  WHERE follower_id = p_user_id
    AND is_active = true
    AND is_mock = false;

  -- Get futures wallet balances
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
    'copy_allocated', v_copy_allocated,
    'copy_available', GREATEST(v_copy_balance - v_copy_locked - v_copy_allocated, 0),
    'futures_available', v_futures_available,
    'futures_locked', v_futures_locked,
    'futures_total', v_futures_available + v_futures_locked,
    'total_trading_available', v_futures_available
  );
END;
$$;
