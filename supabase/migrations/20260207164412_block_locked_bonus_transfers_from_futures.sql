/*
  # Block Locked Bonus Transfers from Futures Wallet

  1. Problem
    - Users with locked bonuses can transfer profits from futures wallet to main wallet
    - This bypasses the locked bonus system entirely
    - Users can then withdraw profits without meeting bonus unlock requirements

  2. Solution
    - When transferring FROM futures wallet, check for ANY locked bonuses that are NOT unlocked
    - If user has active locked bonus: block ALL transfers from futures
    - If user has expired (never unlocked) locked bonus: allow transfer only of amount ABOVE bonus+profits

  3. Changes
    - Update transfer_between_wallets to add locked bonus checks for futures transfers
    - Fix expire_locked_bonuses to deduct bonus from futures wallet on expiry
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
  v_from_balance numeric;
  v_from_locked numeric := 0;
  v_actual_available numeric;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric;
  v_active_promo_bonus numeric := 0;
  v_active_locked_bonus_amount numeric := 0;
  v_active_locked_bonus_profits numeric := 0;
  v_total_locked_bonus_funds numeric := 0;
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

  IF from_wallet_type_param = 'futures' THEN
    SELECT
      COALESCE(SUM(current_amount), 0),
      COALESCE(SUM(realized_profits), 0)
    INTO v_active_locked_bonus_amount, v_active_locked_bonus_profits
    FROM locked_bonuses
    WHERE user_id = user_id_param
    AND is_unlocked = false
    AND status = 'active';

    v_total_locked_bonus_funds := v_active_locked_bonus_amount + v_active_locked_bonus_profits;

    IF v_total_locked_bonus_funds > 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Cannot transfer funds while you have an active locked bonus. Complete the trading volume requirement to unlock your bonus and profits. Locked: $' || ROUND(v_active_locked_bonus_amount, 2) || ', Profits: $' || ROUND(v_active_locked_bonus_profits, 2)
      );
    END IF;

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

CREATE OR REPLACE FUNCTION expire_locked_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_forfeited_total numeric := 0;
  v_expired_bonus record;
  v_current_futures_balance numeric;
  v_forfeit_amount numeric;
BEGIN
  FOR v_expired_bonus IN
    SELECT id, user_id, original_amount, current_amount, realized_profits, bonus_type_name
    FROM locked_bonuses
    WHERE status = 'active'
    AND expires_at <= now()
    AND is_unlocked = false
  LOOP
    v_forfeit_amount := v_expired_bonus.current_amount + v_expired_bonus.realized_profits;

    SELECT available_balance INTO v_current_futures_balance
    FROM futures_margin_wallets
    WHERE user_id = v_expired_bonus.user_id;

    IF v_current_futures_balance IS NOT NULL AND v_current_futures_balance > 0 THEN
      IF v_forfeit_amount > v_current_futures_balance THEN
        v_forfeit_amount := v_current_futures_balance;
      END IF;

      IF v_forfeit_amount > 0 THEN
        UPDATE futures_margin_wallets
        SET
          available_balance = available_balance - v_forfeit_amount,
          updated_at = now()
        WHERE user_id = v_expired_bonus.user_id;

        v_forfeited_total := v_forfeited_total + v_forfeit_amount;

        INSERT INTO transactions (
          user_id,
          transaction_type,
          currency,
          amount,
          status,
          details
        ) VALUES (
          v_expired_bonus.user_id,
          'bonus',
          'USDT',
          -v_forfeit_amount,
          'completed',
          'Locked bonus expired without meeting requirements. Forfeited: $' || ROUND(v_forfeit_amount, 2)
        );
      END IF;
    END IF;

    UPDATE locked_bonuses
    SET
      status = 'expired',
      updated_at = now()
    WHERE id = v_expired_bonus.id;

    UPDATE user_bonuses
    SET status = 'expired'
    WHERE locked_bonus_id = v_expired_bonus.id;

    INSERT INTO notifications (user_id, type, title, message, read, data)
    VALUES (
      v_expired_bonus.user_id,
      'account_update',
      'Locked Bonus Expired',
      'Your locked bonus of $' || ROUND(v_expired_bonus.original_amount, 2) || ' (' || v_expired_bonus.bonus_type_name || ') has expired without meeting unlock requirements. $' || ROUND(v_forfeit_amount, 2) || ' has been forfeited.',
      false,
      jsonb_build_object(
        'locked_bonus_id', v_expired_bonus.id,
        'original_amount', v_expired_bonus.original_amount,
        'forfeited_amount', v_forfeit_amount
      )
    );

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'total_forfeited', v_forfeited_total
  );
END;
$$;
