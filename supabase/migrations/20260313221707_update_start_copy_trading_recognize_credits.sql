/*
  # Update start_copy_trading to Recognize Copy Trading Credits

  1. Changes to the overload with (p_trader_id, p_allocation_percentage, p_leverage, ...)
    - Check for available copy trading credits in addition to wallet balance
    - Credits count toward meeting the 100 USDT minimum
    - If user has 10 USDT credit + 90 USDT real = meets minimum
    - If user has 100 USDT credits + 0 real = also valid
    - When relationship starts, lock credits and set bonus_amount accordingly
    - Credits merge into the existing bonus_amount/bonus_locked_until fields

  2. Credit Locking
    - Mark matched credits as 'locked_in_relationship'
    - Set locked_until on credit records
    - Add credit amount to relationship's bonus_amount
*/

CREATE OR REPLACE FUNCTION start_copy_trading(
  p_trader_id uuid,
  p_allocation_percentage integer,
  p_leverage integer DEFAULT 1,
  p_stop_loss_percent numeric DEFAULT NULL,
  p_take_profit_percent numeric DEFAULT NULL,
  p_is_mock boolean DEFAULT false,
  p_require_approval boolean DEFAULT false
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_follower_id uuid;
  v_existing_relationship copy_relationships;
  v_relationship_id uuid;
  v_trader_exists boolean;
  v_trader_name text;
  v_copy_wallet_id uuid;
  v_wallet_balance numeric;
  v_already_allocated numeric;
  v_available_balance numeric;
  v_initial_balance numeric;
  v_bonus_eligible boolean := false;
  v_bonus_amount numeric := 100;
  v_lock_days integer := 30;
  v_existing_claim_count integer;
  v_minimum_amount numeric := 100;
  v_has_promo_bonus boolean := false;
  v_promo_bonus_amount numeric := 0;
  v_available_credits numeric := 0;
  v_credit_to_use numeric := 0;
  v_total_bonus numeric := 0;
  v_credit_record RECORD;
  v_remaining_credit_to_lock numeric;
BEGIN
  v_follower_id := auth.uid();

  IF v_follower_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_allocation_percentage < 1 OR p_allocation_percentage > 100 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Allocation percentage must be between 1 and 100'
    );
  END IF;

  IF p_leverage < 1 OR p_leverage > 125 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Leverage must be between 1 and 125'
    );
  END IF;

  SELECT EXISTS(SELECT 1 FROM traders WHERE id = p_trader_id), name
  INTO v_trader_exists, v_trader_name
  FROM traders WHERE id = p_trader_id;

  IF NOT v_trader_exists THEN
    RETURN jsonb_build_object('success', false, 'error', 'Trader not found');
  END IF;

  SELECT * INTO v_existing_relationship
  FROM copy_relationships
  WHERE follower_id = v_follower_id
    AND trader_id = p_trader_id
    AND is_mock = p_is_mock;

  IF FOUND AND v_existing_relationship.status = 'active' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You are already copying this trader in ' ||
        CASE WHEN p_is_mock THEN 'mock' ELSE 'real' END || ' mode'
    );
  END IF;

  SELECT COALESCE(SUM(pcr.bonus_amount), 0) INTO v_promo_bonus_amount
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = v_follower_id
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now()
    AND pc.bonus_type = 'copy_trading_only';

  IF v_promo_bonus_amount > 0 THEN
    v_has_promo_bonus := true;
    v_minimum_amount := LEAST(v_promo_bonus_amount, 100);
  END IF;

  IF NOT p_is_mock THEN
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_available_credits
    FROM copy_trading_credits
    WHERE user_id = v_follower_id
      AND status = 'available';

    IF v_available_credits > 0 AND NOT v_has_promo_bonus THEN
      v_minimum_amount := GREATEST(LEAST(v_available_credits, 100), 20);
    END IF;
  END IF;

  IF p_is_mock THEN
    v_initial_balance := 10000.0 * p_allocation_percentage / 100.0;
  ELSE
    SELECT balance INTO v_wallet_balance
    FROM wallets
    WHERE user_id = v_follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

    IF v_wallet_balance IS NULL THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
      VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
      ON CONFLICT (user_id, currency, wallet_type)
      DO UPDATE SET updated_at = NOW()
      RETURNING balance INTO v_wallet_balance;
    END IF;

    SELECT COALESCE(SUM(initial_balance), 0) INTO v_already_allocated
    FROM copy_relationships
    WHERE follower_id = v_follower_id
      AND is_active = true
      AND is_mock = false
      AND trader_id != p_trader_id;

    v_available_balance := GREATEST(0, v_wallet_balance - v_already_allocated);

    IF v_available_balance < v_minimum_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Minimum available balance of ' || v_minimum_amount || ' USDT required. You have ' ||
          ROUND(v_available_balance, 2)::text || ' USDT available (Total: ' ||
          ROUND(v_wallet_balance, 2)::text || ' - Allocated: ' ||
          ROUND(v_already_allocated, 2)::text || ')' ||
          CASE WHEN v_available_credits > 0 THEN
            ' (includes $' || ROUND(v_available_credits, 2)::text || ' in copy trading credits)'
          ELSE '' END
      );
    END IF;

    v_initial_balance := v_available_balance * p_allocation_percentage / 100.0;

    IF v_initial_balance < v_minimum_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Calculated allocation is ' || ROUND(v_initial_balance, 2)::text ||
          ' USDT but minimum is ' || v_minimum_amount || ' USDT. Increase your allocation percentage.'
      );
    END IF;

    v_credit_to_use := LEAST(v_available_credits, v_initial_balance);

    IF v_initial_balance >= 500 AND NOT v_has_promo_bonus AND v_credit_to_use = 0 THEN
      SELECT COUNT(*) INTO v_existing_claim_count
      FROM copy_trading_bonus_claims
      WHERE user_id = v_follower_id;

      IF v_existing_claim_count = 0 THEN
        v_bonus_eligible := true;
      END IF;
    END IF;

    v_total_bonus := v_credit_to_use;
    IF v_bonus_eligible THEN
      v_total_bonus := v_total_bonus + v_bonus_amount;
    END IF;
  END IF;

  IF FOUND AND v_existing_relationship.status IN ('stopped', 'paused') THEN
    UPDATE copy_relationships
    SET
      is_active = true,
      status = 'active',
      allocation_percentage = p_allocation_percentage,
      leverage = p_leverage,
      stop_loss_percent = p_stop_loss_percent,
      take_profit_percent = p_take_profit_percent,
      require_approval = p_require_approval,
      initial_balance = v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
      current_balance = v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
      cumulative_pnl = 0,
      total_pnl = 0,
      bonus_amount = v_total_bonus,
      bonus_locked_until = CASE WHEN v_total_bonus > 0 THEN now() + (v_lock_days || ' days')::interval ELSE NULL END,
      ended_at = NULL,
      updated_at = NOW()
    WHERE id = v_existing_relationship.id
    RETURNING id INTO v_relationship_id;

    IF v_bonus_eligible AND NOT p_is_mock THEN
      UPDATE wallets
      SET balance = balance + v_bonus_amount, updated_at = now()
      WHERE user_id = v_follower_id AND currency = 'USDT' AND wallet_type = 'copy';

      INSERT INTO copy_trading_bonus_claims (user_id, relationship_id, amount, claimed_at)
      VALUES (v_follower_id, v_relationship_id, v_bonus_amount, now());

      INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
      VALUES (
        v_follower_id, 'reward', 'Copy Trading Bonus!',
        'You received 100 USDT bonus on your copy trading with ' || COALESCE(v_trader_name, 'trader') || '. Keep it for 30 days to unlock!',
        false,
        jsonb_build_object('bonus_amount', v_bonus_amount, 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
        now()
      );

      INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
      VALUES (v_follower_id, 'reward', 'USDT', v_bonus_amount, 'completed',
        jsonb_build_object('type', 'copy_trading_bonus', 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
        now()
      );
    END IF;

    IF v_credit_to_use > 0 AND NOT p_is_mock THEN
      v_remaining_credit_to_lock := v_credit_to_use;
      FOR v_credit_record IN
        SELECT id, remaining_amount
        FROM copy_trading_credits
        WHERE user_id = v_follower_id AND status = 'available'
        ORDER BY created_at ASC
      LOOP
        IF v_remaining_credit_to_lock <= 0 THEN EXIT; END IF;

        IF v_credit_record.remaining_amount <= v_remaining_credit_to_lock THEN
          UPDATE copy_trading_credits
          SET status = 'locked_in_relationship',
              relationship_id = v_relationship_id,
              locked_until = now() + (lock_days || ' days')::interval,
              updated_at = now()
          WHERE id = v_credit_record.id;
          v_remaining_credit_to_lock := v_remaining_credit_to_lock - v_credit_record.remaining_amount;
        ELSE
          UPDATE copy_trading_credits
          SET status = 'locked_in_relationship',
              relationship_id = v_relationship_id,
              remaining_amount = v_remaining_credit_to_lock,
              locked_until = now() + (lock_days || ' days')::interval,
              updated_at = now()
          WHERE id = v_credit_record.id;
          v_remaining_credit_to_lock := 0;
        END IF;
      END LOOP;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'relationship_id', v_relationship_id,
      'message', CASE
        WHEN v_bonus_eligible AND v_credit_to_use > 0 THEN 'Copy trading restarted with 100 USDT bonus + $' || ROUND(v_credit_to_use, 2)::text || ' credit!'
        WHEN v_bonus_eligible THEN 'Copy trading restarted with 100 USDT bonus!'
        WHEN v_credit_to_use > 0 THEN 'Copy trading restarted with $' || ROUND(v_credit_to_use, 2)::text || ' credit applied!'
        ELSE 'Copy trading restarted successfully'
      END,
      'initial_balance', v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
      'bonus_granted', v_bonus_eligible,
      'bonus_amount', CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END,
      'credit_applied', v_credit_to_use
    );
  END IF;

  SELECT id INTO v_copy_wallet_id
  FROM wallets
  WHERE user_id = v_follower_id
    AND wallet_type = 'copy'
    AND currency = 'USDT';

  IF v_copy_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (v_follower_id, 'USDT', 'copy', 0, 0)
    ON CONFLICT (user_id, currency, wallet_type)
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_copy_wallet_id;
  END IF;

  INSERT INTO copy_relationships (
    follower_id, trader_id, is_active, allocation_percentage, leverage,
    stop_loss_percent, take_profit_percent, initial_balance, current_balance,
    total_pnl, is_mock, status, require_approval,
    bonus_amount, bonus_locked_until
  ) VALUES (
    v_follower_id, p_trader_id, true, p_allocation_percentage, p_leverage,
    p_stop_loss_percent, p_take_profit_percent,
    v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
    v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
    0, p_is_mock, 'active', p_require_approval,
    v_total_bonus,
    CASE WHEN v_total_bonus > 0 THEN now() + (v_lock_days || ' days')::interval ELSE NULL END
  )
  RETURNING id INTO v_relationship_id;

  IF v_bonus_eligible AND NOT p_is_mock THEN
    UPDATE wallets
    SET balance = balance + v_bonus_amount, updated_at = now()
    WHERE user_id = v_follower_id AND currency = 'USDT' AND wallet_type = 'copy';

    INSERT INTO copy_trading_bonus_claims (user_id, relationship_id, amount, claimed_at)
    VALUES (v_follower_id, v_relationship_id, v_bonus_amount, now());

    INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
    VALUES (
      v_follower_id, 'reward', 'Copy Trading Bonus!',
      'You received 100 USDT bonus on your copy trading with ' || COALESCE(v_trader_name, 'trader') || '. Keep it for 30 days to unlock!',
      false,
      jsonb_build_object('bonus_amount', v_bonus_amount, 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
      now()
    );

    INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details, confirmed_at)
    VALUES (v_follower_id, 'reward', 'USDT', v_bonus_amount, 'completed',
      jsonb_build_object('type', 'copy_trading_bonus', 'relationship_id', v_relationship_id, 'trader_name', v_trader_name),
      now()
    );
  END IF;

  IF v_credit_to_use > 0 AND NOT p_is_mock THEN
    v_remaining_credit_to_lock := v_credit_to_use;
    FOR v_credit_record IN
      SELECT id, remaining_amount
      FROM copy_trading_credits
      WHERE user_id = v_follower_id AND status = 'available'
      ORDER BY created_at ASC
    LOOP
      IF v_remaining_credit_to_lock <= 0 THEN EXIT; END IF;

      IF v_credit_record.remaining_amount <= v_remaining_credit_to_lock THEN
        UPDATE copy_trading_credits
        SET status = 'locked_in_relationship',
            relationship_id = v_relationship_id,
            locked_until = now() + (lock_days || ' days')::interval,
            updated_at = now()
        WHERE id = v_credit_record.id;
        v_remaining_credit_to_lock := v_remaining_credit_to_lock - v_credit_record.remaining_amount;
      ELSE
        UPDATE copy_trading_credits
        SET status = 'locked_in_relationship',
            relationship_id = v_relationship_id,
            remaining_amount = v_remaining_credit_to_lock,
            locked_until = now() + (lock_days || ' days')::interval,
            updated_at = now()
        WHERE id = v_credit_record.id;
        v_remaining_credit_to_lock := 0;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'relationship_id', v_relationship_id,
    'message', CASE
      WHEN v_bonus_eligible AND v_credit_to_use > 0 THEN 'Copy trading started with 100 USDT bonus + $' || ROUND(v_credit_to_use, 2)::text || ' credit!'
      WHEN v_bonus_eligible THEN 'Copy trading started with 100 USDT bonus!'
      WHEN v_credit_to_use > 0 THEN 'Copy trading started with $' || ROUND(v_credit_to_use, 2)::text || ' credit applied!'
      ELSE 'Copy trading started successfully'
    END,
    'initial_balance', v_initial_balance + (CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END),
    'bonus_granted', v_bonus_eligible,
    'bonus_amount', CASE WHEN v_bonus_eligible THEN v_bonus_amount ELSE 0 END,
    'credit_applied', v_credit_to_use
  );
END;
$$;
