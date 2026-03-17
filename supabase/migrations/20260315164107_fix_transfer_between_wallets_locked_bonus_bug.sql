/*
  # Fix Transfer Between Wallets - Locked Bonus Blocking Bug

  ## Critical Bug Description
  The transfer_between_wallets function incorrectly blocks legitimate user funds
  from being transferred out of the futures wallet.

  ## Root Cause
  1. Locked bonuses are stored in the `locked_bonuses` table (separate from wallet balance)
  2. award_locked_bonus() only writes to locked_bonuses, NOT to futures_margin_wallets
  3. futures_margin_wallets.available_balance contains ONLY real deposited funds
  4. But transfer function subtracts locked_bonuses from available_balance, incorrectly assuming they overlap

  ## Example of Bug
  - User deposits: $509.94 (real money)
  - User receives: $306.22 locked bonus (stored in locked_bonuses table only)
  - User transfers to futures: $493 (real money from main wallet)
  - Futures wallet shows: $306.96 available (100% real deposits)
  - Locked bonuses table shows: $306.22 (separate bonus credits)
  - Current buggy logic: transferable = $306.96 - $306.22 = $0.74
  - User cannot transfer their own deposited money!

  ## Correct Logic
  The futures wallet balance and locked bonuses are INDEPENDENT:
  - futures_margin_wallets.available_balance = Real deposits that can be transferred
  - locked_bonuses = Bonus credits used for margin (cannot be transferred until unlocked)
  - These two pools do NOT overlap

  ## What Should Be Blocked
  1. Profits from trades funded by locked bonuses (tracked in locked_bonuses.realized_profits)
  2. Funds that are currently used as margin in open positions
  3. NOT the entire wallet balance just because bonuses exist

  ## Solution
  1. Remove the incorrect subtraction of locked bonus amounts from transferable calculation
  2. Only check if profits from bonus-funded trades are trying to be withdrawn
  3. Track which portion of futures balance comes from bonus profits vs real deposits
  4. Use total_deposited and total_withdrawn to calculate real funds available
*/

-- ============================================
-- Fix transfer_between_wallets function
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
  v_futures_total_deposited numeric := 0;
  v_futures_total_withdrawn numeric := 0;
  v_margin_in_open_positions numeric := 0;
  v_locked_bonus_margin_used numeric := 0;
  v_real_balance_estimate numeric := 0;
  v_bonus_profits numeric := 0;
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

  -- Block promo bonus transfers from copy wallet
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
    SELECT
      COALESCE(available_balance, 0),
      COALESCE(total_deposited, 0),
      COALESCE(total_withdrawn, 0)
    INTO v_futures_available, v_futures_total_deposited, v_futures_total_withdrawn
    FROM futures_margin_wallets
    WHERE user_id = user_id_param
    FOR UPDATE;

    IF v_futures_available IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Futures wallet not found');
    END IF;

    -- Calculate margin currently locked in open positions
    SELECT COALESCE(SUM(margin_allocated), 0)
    INTO v_margin_in_open_positions
    FROM futures_positions
    WHERE user_id = user_id_param
    AND status = 'open';

    -- Calculate how much margin in open positions is from locked bonuses
    SELECT COALESCE(SUM(margin_from_locked_bonus), 0)
    INTO v_locked_bonus_margin_used
    FROM futures_positions
    WHERE user_id = user_id_param
    AND status = 'open';

    -- Get total profits from locked bonus trades
    SELECT COALESCE(SUM(realized_profits), 0)
    INTO v_bonus_profits
    FROM locked_bonuses
    WHERE user_id = user_id_param
    AND status = 'active'
    AND is_unlocked = false;

    -- Calculate real balance = money deposited into futures - money withdrawn
    -- This represents the user's actual deposited funds
    v_real_balance_estimate := v_futures_total_deposited - v_futures_total_withdrawn;

    -- The transferable amount is the MINIMUM of:
    -- 1. Available balance (not in positions)
    -- 2. Real deposited funds (excluding bonus profits)
    v_transferable := LEAST(
      v_futures_available - v_margin_in_open_positions,
      GREATEST(v_real_balance_estimate - v_bonus_profits, 0)
    );

    -- Ensure transferable is never negative
    v_transferable := GREATEST(v_transferable, 0);

    IF amount_param > v_futures_available - v_margin_in_open_positions THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Insufficient available balance. $' || ROUND(v_margin_in_open_positions, 2) || ' is locked in open positions.'
      );
    END IF;

    IF amount_param > v_transferable THEN
      IF v_bonus_profits > 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'Amount exceeds transferable balance. You can transfer up to $' || ROUND(v_transferable, 2) || ' USDT. The remaining balance includes $' || ROUND(v_bonus_profits, 2) || ' in profits from locked bonus trades, which can only be withdrawn after the bonus is unlocked.'
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'Amount exceeds transferable balance. You can transfer up to $' || ROUND(v_transferable, 2) || ' USDT.'
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
