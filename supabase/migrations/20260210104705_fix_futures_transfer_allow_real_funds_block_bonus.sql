/*
  # Fix Futures Transfers: Allow Real Funds, Block Bonus Funds

  ## Problem
  The transfer_between_wallets function blocks ALL transfers from futures wallet
  when a user has any active locked bonus. This prevents users from transferring
  their real deposited funds.

  ## Solution
  1. Calculate transferable = available_balance - locked_bonus_total
  2. Allow transfers up to the transferable amount (real funds only)
  3. Block transfers that would eat into bonus funds
  4. Update get_wallet_balances to return `futures_transferable`

  ## Changes
  - `transfer_between_wallets`: Replace blanket block with amount-based check
  - `get_wallet_balances`: Add `futures_transferable` field
*/

-- ============================================
-- STEP 1: Fix transfer_between_wallets
-- ============================================
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
  v_from_locked numeric := 0;
  v_actual_available numeric;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric;
  v_active_promo_bonus numeric := 0;
  v_active_locked_bonus_amount numeric := 0;
  v_active_locked_bonus_profits numeric := 0;
  v_total_locked_bonus_funds numeric := 0;
  v_transferable numeric := 0;
BEGIN
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

  IF from_wallet_type_param = 'copy' THEN
    SELECT COALESCE(SUM(pcr.bonus_amount), 0) INTO v_active_promo_bonus
    FROM promo_code_redemptions pcr
    JOIN promo_codes pc ON pc.id = pcr.promo_code_id
    WHERE pcr.user_id = user_id_param
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now()
    AND pc.bonus_type = 'copy_trading_only';

    IF v_active_promo_bonus > 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Cannot transfer promo bonus funds. Your $' || ROUND(v_active_promo_bonus, 2) || ' copy trading bonus can only be used for copy trading. You can withdraw any profits you make, but not the bonus itself.'
      );
    END IF;
  END IF;

  -- =============================================
  -- FUTURES -> other wallet transfer
  -- =============================================
  IF from_wallet_type_param = 'futures' THEN
    SELECT available_balance INTO v_futures_available
    FROM futures_margin_wallets
    WHERE user_id = user_id_param
    FOR UPDATE;

    IF v_futures_available IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet not found');
    END IF;

    SELECT
      COALESCE(SUM(current_amount), 0),
      COALESCE(SUM(realized_profits), 0)
    INTO v_active_locked_bonus_amount, v_active_locked_bonus_profits
    FROM locked_bonuses
    WHERE user_id = user_id_param
    AND is_unlocked = false
    AND status = 'active';

    v_total_locked_bonus_funds := v_active_locked_bonus_amount + v_active_locked_bonus_profits;
    v_transferable := GREATEST(v_futures_available - v_total_locked_bonus_funds, 0);

    IF v_transferable < amount_param THEN
      IF v_transferable <= 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'No transferable funds. Your futures balance of $' || ROUND(v_futures_available, 2) || ' consists entirely of locked bonus funds ($' || ROUND(v_total_locked_bonus_funds, 2) || '). Complete the trading volume requirement to unlock.'
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'Amount exceeds transferable balance. You can transfer up to $' || ROUND(v_transferable, 2) || ' USDT. The remaining $' || ROUND(v_total_locked_bonus_funds, 2) || ' is locked bonus funds.'
        );
      END IF;
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
        CASE to_wallet_type_param WHEN 'main' THEN 'Main' WHEN 'copy' THEN 'Copy Trading' ELSE to_wallet_type_param END || ' wallet'
    );
  END IF;

  -- =============================================
  -- other wallet -> FUTURES transfer
  -- =============================================
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

    INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance, total_deposited, total_withdrawn, created_at, updated_at)
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

  -- =============================================
  -- Non-futures transfers (main<->copy, etc.)
  -- =============================================
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

-- ============================================
-- STEP 2: Fix get_wallet_balances to return futures_transferable
-- ============================================
CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_main_locked numeric := 0;
  v_copy_balance numeric := 0;
  v_copy_locked numeric := 0;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric := 0;
  v_futures_locked numeric := 0;
  v_locked_bonus_balance numeric := 0;
  v_locked_bonus_profits numeric := 0;
  v_margin_in_positions numeric := 0;
  v_total_locked_bonus numeric := 0;
  v_futures_transferable numeric := 0;
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

  SELECT
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(realized_profits), 0)
  INTO v_locked_bonus_balance, v_locked_bonus_profits
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active'
    AND is_unlocked = false;

  v_total_locked_bonus := v_locked_bonus_balance + v_locked_bonus_profits;
  v_futures_transferable := GREATEST(v_futures_available - v_total_locked_bonus, 0);

  SELECT COALESCE(SUM(margin_allocated), 0)
  INTO v_margin_in_positions
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'open';

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
    'futures_transferable', v_futures_transferable,
    'futures_locked_bonus', v_total_locked_bonus,
    'futures', jsonb_build_object(
      'available_balance', v_futures_available,
      'locked_balance', v_futures_locked,
      'total_equity', v_futures_available + v_futures_locked,
      'margin_in_positions', v_margin_in_positions,
      'transferable', v_futures_transferable,
      'locked_bonus', v_total_locked_bonus
    ),
    'locked_bonus', jsonb_build_object(
      'balance', v_locked_bonus_balance
    ),
    'total_trading_available', v_futures_available + v_locked_bonus_balance
  );
END;
$$;
