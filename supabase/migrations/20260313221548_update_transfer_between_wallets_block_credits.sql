/*
  # Update transfer_between_wallets to Block Copy Trading Credits

  1. Changes
    - When transferring FROM copy wallet, calculate total active credits
    - Block transfers that would bring copy wallet balance below active credit amount
    - Credits are non-transferable and non-withdrawable

  2. Logic
    - Sum all copy_trading_credits with status 'available' or 'locked_in_relationship'
    - The user can only transfer real funds above the credit amount
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
  v_transferable numeric := 0;
  v_locked_margin_in_positions numeric := 0;
  v_active_count int;
  v_active_relationship copy_relationships;
  v_new_initial_balance numeric;
  v_new_current_balance numeric;
  v_active_credits numeric := 0;
BEGIN
  IF amount_param <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  IF from_wallet_type_param NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF to_wallet_type_param NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  IF from_wallet_type_param = to_wallet_type_param THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to the same wallet');
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

    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_active_credits
    FROM copy_trading_credits
    WHERE user_id = user_id_param
      AND status IN ('available', 'locked_in_relationship');
  END IF;

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

    SELECT COALESCE(SUM(fp.margin_from_locked_bonus), 0) INTO v_locked_margin_in_positions
    FROM futures_positions fp
    WHERE fp.user_id = user_id_param
      AND fp.status = 'open';

    v_total_locked_bonus_funds := v_total_locked_bonus_funds + v_locked_margin_in_positions;
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

  ELSIF from_wallet_type_param = 'copy' THEN
    SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
    INTO v_from_balance, v_from_locked
    FROM wallets
    WHERE user_id = user_id_param
      AND wallet_type = 'copy'
      AND currency = currency_param
    FOR UPDATE;

    SELECT COALESCE(SUM(COALESCE(current_balance, initial_balance, 0)), 0) INTO v_allocated_to_traders
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND status IN ('active', 'pending')
      AND is_mock = false;

    v_actual_available := COALESCE(v_from_balance, 0) - v_from_locked - v_allocated_to_traders - v_active_credits;

    IF v_actual_available < amount_param THEN
      IF v_active_credits > 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'Insufficient transferable balance. Available: $' || ROUND(GREATEST(v_actual_available, 0), 2) ||
            ' (Total: $' || ROUND(v_from_balance, 2) ||
            ', Allocated: $' || ROUND(v_allocated_to_traders, 2) ||
            ', Non-transferable credits: $' || ROUND(v_active_credits, 2) || ')'
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', format('Insufficient available balance. Available: $%.2f (Total: $%.2f, Allocated: $%.2f)',
            GREATEST(v_actual_available, 0), v_from_balance, v_allocated_to_traders)
        );
      END IF;
    END IF;

    UPDATE wallets
    SET balance = balance - amount_param,
        updated_at = now()
    WHERE user_id = user_id_param
      AND wallet_type = 'copy'
      AND currency = currency_param;

  ELSE
    SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
    INTO v_from_balance, v_from_locked
    FROM wallets
    WHERE user_id = user_id_param
      AND wallet_type = from_wallet_type_param
      AND currency = currency_param
    FOR UPDATE;

    IF v_from_balance IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Source wallet not found');
    END IF;

    v_actual_available := v_from_balance - v_from_locked;

    IF v_actual_available < amount_param THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    UPDATE wallets
    SET balance = balance - amount_param,
        updated_at = now()
    WHERE user_id = user_id_param
      AND wallet_type = from_wallet_type_param
      AND currency = currency_param;
  END IF;

  IF to_wallet_type_param = 'futures' THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance, total_deposited, total_withdrawn, created_at, updated_at)
    VALUES (user_id_param, amount_param, 0, amount_param, 0, now(), now())
    ON CONFLICT (user_id) DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + amount_param,
      total_deposited = futures_margin_wallets.total_deposited + amount_param,
      updated_at = now();
  ELSE
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
    VALUES (user_id_param, currency_param, to_wallet_type_param, amount_param, 0, now(), now())
    ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET
      balance = wallets.balance + amount_param,
      updated_at = now();
  END IF;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, confirmed_at)
  VALUES (user_id_param, 'transfer', currency_param, amount_param, 0, 'completed', now());

  IF to_wallet_type_param = 'copy' THEN
    SELECT COUNT(*) INTO v_active_count
    FROM copy_relationships
    WHERE follower_id = user_id_param
      AND is_active = true
      AND is_mock = false
      AND status = 'active';

    IF v_active_count = 1 THEN
      SELECT * INTO v_active_relationship
      FROM copy_relationships
      WHERE follower_id = user_id_param
        AND is_active = true
        AND is_mock = false
        AND status = 'active';

      v_new_initial_balance := COALESCE(v_active_relationship.initial_balance, 0) + amount_param;
      v_new_current_balance := COALESCE(v_active_relationship.current_balance, 0) + amount_param;

      UPDATE copy_relationships
      SET initial_balance = v_new_initial_balance,
          current_balance = v_new_current_balance,
          updated_at = now()
      WHERE id = v_active_relationship.id;

      INSERT INTO transactions (
        user_id, transaction_type, currency, amount, status, details
      ) VALUES (
        user_id_param, 'copy_topup', 'USDT', amount_param, 'completed',
        jsonb_build_object(
          'relationship_id', v_active_relationship.id,
          'trader_id', v_active_relationship.trader_id,
          'previous_initial_balance', v_active_relationship.initial_balance,
          'new_initial_balance', v_new_initial_balance,
          'previous_current_balance', v_active_relationship.current_balance,
          'new_current_balance', v_new_current_balance,
          'auto_allocated', true
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Transferred ' || ROUND(amount_param, 2)::text || ' ' || currency_param || ' from ' ||
      from_wallet_type_param || ' to ' || to_wallet_type_param || ' wallet'
  );
END;
$$;
