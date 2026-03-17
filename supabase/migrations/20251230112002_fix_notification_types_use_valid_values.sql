/*
  # Fix Notification Types - Use Valid Values

  ## Summary
  Updates notification inserts to use valid types from the constraint.
  'reward' is not valid - use 'bonus' instead.
  'warning' is not valid - use 'system' instead.

  ## Valid Types
  referral_payout, trade_executed, kyc_update, account_update, system,
  copy_trade, position_closed, position_sl_hit, position_tp_hit,
  position_liquidated, vip_downgrade, vip_upgrade, shark_card_application,
  withdrawal_completed, withdrawal_rejected, bonus, affiliate_payout,
  pending_copy_trade, deposit_completed, deposit_failed
*/

-- Fix check_and_unlock_bonus - use 'bonus' type
CREATE OR REPLACE FUNCTION check_and_unlock_bonus(p_locked_bonus_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus record;
  v_unlocked_amount numeric;
  v_realized_profits numeric;
BEGIN
  SELECT * INTO v_bonus
  FROM locked_bonuses
  WHERE id = p_locked_bonus_id
    AND status = 'active'
    AND COALESCE(is_unlocked, false) = false
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus not found, already unlocked, or expired'
    );
  END IF;

  IF v_bonus.bonus_trading_volume_completed < v_bonus.bonus_trading_volume_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'requirements_met', false,
      'volume_required', v_bonus.bonus_trading_volume_required,
      'volume_completed', v_bonus.bonus_trading_volume_completed,
      'volume_remaining', v_bonus.bonus_trading_volume_required - v_bonus.bonus_trading_volume_completed,
      'percentage_complete', ROUND((v_bonus.bonus_trading_volume_completed / v_bonus.bonus_trading_volume_required * 100)::numeric, 2)
    );
  END IF;

  v_unlocked_amount := v_bonus.current_amount;
  v_realized_profits := v_bonus.realized_profits;

  UPDATE locked_bonuses
  SET is_unlocked = true, unlocked_at = now(), status = 'unlocked', updated_at = now()
  WHERE id = p_locked_bonus_id;

  IF v_unlocked_amount > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_unlocked_amount, updated_at = now()
    WHERE user_id = v_bonus.user_id;

    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_bonus.user_id, v_unlocked_amount, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_unlocked_amount,
        updated_at = now();
    END IF;
  END IF;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (
    v_bonus.user_id, 'bonus', 'USDT', v_unlocked_amount, 'completed',
    'Locked Bonus Unlocked: ' || v_bonus.bonus_type_name || 
    '. Volume completed: $' || ROUND(v_bonus.bonus_trading_volume_completed, 2)::text ||
    ' / $' || ROUND(v_bonus.bonus_trading_volume_required, 2)::text ||
    '. Profits earned: $' || ROUND(v_realized_profits, 2)::text
  );

  INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
  VALUES (
    v_bonus.user_id,
    'bonus',
    'Bonus Unlocked!',
    'Congratulations! You completed $' || ROUND(v_bonus.bonus_trading_volume_completed::numeric, 2)::text || 
    ' in trading volume and unlocked your ' || v_bonus.bonus_type_name || ' bonus of $' || 
    ROUND(v_unlocked_amount::numeric, 2)::text || ' USDT! This amount is now withdrawable.' ||
    CASE WHEN v_realized_profits > 0 
      THEN ' You also earned $' || ROUND(v_realized_profits::numeric, 2)::text || ' in profits!'
      ELSE ''
    END,
    false,
    jsonb_build_object(
      'locked_bonus_id', p_locked_bonus_id,
      'unlocked_amount', v_unlocked_amount,
      'realized_profits', v_realized_profits,
      'bonus_type', v_bonus.bonus_type_name
    ),
    '/wallet'
  );

  RETURN jsonb_build_object(
    'success', true,
    'unlocked', true,
    'amount', v_unlocked_amount,
    'realized_profits', v_realized_profits,
    'volume_completed', v_bonus.bonus_trading_volume_completed,
    'message', 'Bonus unlocked successfully!'
  );
END;
$$;

-- Fix close_position - use valid notification types
CREATE OR REPLACE FUNCTION close_position(
  p_position_id UUID,
  p_close_price NUMERIC DEFAULT NULL,
  p_close_quantity NUMERIC DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_position RECORD;
  v_current_price NUMERIC;
  v_pnl NUMERIC;
  v_close_qty NUMERIC;
  v_margin_return NUMERIC;
  v_margin_from_locked NUMERIC;
  v_margin_from_regular NUMERIC;
  v_oldest_bonus_id UUID;
  v_notional_value NUMERIC;
  v_closing_fee NUMERIC;
  v_fee_rate NUMERIC;
  v_net_pnl NUMERIC;
  v_transaction_id UUID;
  v_volume_contribution RECORD;
  v_bonus_volume NUMERIC;
  v_real_volume NUMERIC;
  v_duration_met BOOLEAN;
  v_duration_minutes NUMERIC;
  v_bonus_unlockable BOOLEAN;
BEGIN
  SELECT * INTO v_position FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open' FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  IF p_close_price IS NOT NULL AND p_close_price > 0 THEN
    v_current_price := p_close_price;
  ELSE
    SELECT last_price INTO v_current_price FROM market_prices WHERE pair = v_position.pair;
    IF v_current_price IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Could not get market price');
    END IF;
  END IF;

  IF p_close_quantity IS NOT NULL AND p_close_quantity > 0 THEN
    v_close_qty := LEAST(p_close_quantity, v_position.quantity);
  ELSE
    v_close_qty := v_position.quantity;
  END IF;

  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_close_qty;
  END IF;

  SELECT COALESCE(taker_fee, 0.0004) INTO v_fee_rate 
  FROM trading_pairs_config WHERE pair = v_position.pair;
  IF v_fee_rate IS NULL THEN v_fee_rate := 0.0004; END IF;

  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0);
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0) * (v_close_qty / v_position.quantity);
  END IF;

  v_margin_from_regular := v_margin_return - v_margin_from_locked;
  v_notional_value := v_close_qty * v_current_price;
  v_closing_fee := v_notional_value * v_fee_rate;
  v_net_pnl := v_pnl - v_closing_fee;

  SELECT * INTO v_volume_contribution FROM calculate_volume_contribution(
    v_close_qty, v_position.entry_price, v_margin_return, v_margin_from_locked,
    v_position.opened_at, now(), 60
  );

  v_bonus_volume := v_volume_contribution.bonus_volume;
  v_real_volume := v_volume_contribution.real_volume;
  v_duration_met := v_volume_contribution.duration_met;
  v_duration_minutes := EXTRACT(EPOCH FROM (now() - v_position.opened_at)) / 60;

  IF v_margin_from_locked > 0 THEN
    SELECT id INTO v_oldest_bonus_id FROM locked_bonuses
    WHERE user_id = v_position.user_id AND status = 'active' AND expires_at > now()
    ORDER BY created_at ASC LIMIT 1;

    IF v_oldest_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET current_amount = current_amount + v_margin_from_locked, updated_at = now()
      WHERE id = v_oldest_bonus_id;

      IF v_duration_met AND v_bonus_volume > 0 THEN
        UPDATE locked_bonuses
        SET bonus_trading_volume_completed = bonus_trading_volume_completed + v_bonus_volume, updated_at = now()
        WHERE id = v_oldest_bonus_id;

        SELECT is_bonus_unlockable(v_oldest_bonus_id) INTO v_bonus_unlockable;

        IF v_bonus_unlockable THEN
          INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
          VALUES (v_position.user_id, 'bonus', 'Bonus Ready to Unlock!',
            'You have completed the trading volume requirement for your locked bonus! Visit your wallet to unlock it.',
            false, jsonb_build_object('locked_bonus_id', v_oldest_bonus_id, 'action', 'unlock_bonus'), '/wallet'
          );
        END IF;
      ELSIF v_margin_from_locked > 0 AND NOT v_duration_met THEN
        INSERT INTO notifications (user_id, type, title, message, read, data)
        VALUES (v_position.user_id, 'system', 'Position Closed Early',
          'Your position was closed after only ' || ROUND(v_duration_minutes::numeric, 1) || ' minutes. Positions using locked bonus funds must be held for at least 60 minutes to count toward unlock requirements.',
          false, jsonb_build_object('position_id', p_position_id, 'duration_minutes', ROUND(v_duration_minutes::numeric, 1), 'required_minutes', 60)
        );
      END IF;
    ELSE
      v_margin_from_regular := v_margin_from_regular + v_margin_from_locked;
      v_margin_from_locked := 0;
    END IF;
  END IF;

  IF v_real_volume > 0 THEN
    INSERT INTO referral_stats (user_id, total_volume_all_time, total_volume_30d, updated_at)
    VALUES (v_position.user_id, v_real_volume, v_real_volume, now())
    ON CONFLICT (user_id) DO UPDATE SET
      total_volume_all_time = referral_stats.total_volume_all_time + v_real_volume,
      total_volume_30d = referral_stats.total_volume_30d + v_real_volume,
      updated_at = now();
  END IF;

  IF v_margin_from_regular > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_from_regular,
        locked_balance = GREATEST(locked_balance - v_margin_return, 0), updated_at = now()
    WHERE user_id = v_position.user_id;
    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_margin_from_regular, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_margin_from_regular,
        locked_balance = GREATEST(futures_margin_wallets.locked_balance - v_margin_return, 0), updated_at = now();
    END IF;
  ELSE
    UPDATE futures_margin_wallets
    SET locked_balance = GREATEST(locked_balance - v_margin_return, 0), updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;

  IF v_net_pnl >= 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_net_pnl, updated_at = now()
    WHERE user_id = v_position.user_id;
    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_net_pnl, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_net_pnl, updated_at = now();
    END IF;
    IF v_oldest_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses SET realized_profits = realized_profits + v_net_pnl, updated_at = now()
      WHERE id = v_oldest_bonus_id;
    END IF;
  ELSE
    PERFORM apply_pnl_to_locked_bonus(v_position.user_id, v_net_pnl);
  END IF;

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (v_position.user_id, 'futures_close', 'USDT', GREATEST(ABS(v_net_pnl), 0.01), 'completed',
    'Closed ' || v_position.pair || ' ' || upper(v_position.side) || '. PnL: ' || 
    CASE WHEN v_net_pnl >= 0 THEN '+' ELSE '' END || round(v_net_pnl, 2) || ' USDT (Fee: ' || round(v_closing_fee, 4) || ')')
  RETURNING id INTO v_transaction_id;

  IF v_closing_fee > 0.0001 THEN
    INSERT INTO fee_collections (user_id, position_id, fee_type, fee_amount, notional_size, pair, fee_rate, currency)
    VALUES (v_position.user_id, p_position_id, 'futures_close', v_closing_fee, v_notional_value, v_position.pair, v_fee_rate, 'USDT');
  END IF;

  IF v_close_qty = v_position.quantity THEN
    UPDATE futures_positions
    SET status = 'closed', realized_pnl = v_net_pnl, mark_price = v_current_price,
        cumulative_fees = COALESCE(cumulative_fees, 0) + v_closing_fee, closed_at = now()
    WHERE position_id = p_position_id;
  ELSE
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty, margin_allocated = margin_allocated - v_margin_return,
        margin_from_locked_bonus = COALESCE(margin_from_locked_bonus, 0) - v_margin_from_locked,
        cumulative_fees = COALESCE(cumulative_fees, 0) + v_closing_fee, mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'position_id', p_position_id, 'closed_quantity', v_close_qty,
    'exit_price', v_current_price, 'pnl', round(v_pnl, 8), 'closing_fee', round(v_closing_fee, 8),
    'net_pnl', round(v_net_pnl, 8), 'notional_value', round(v_notional_value, 2),
    'margin_returned_to_locked_bonus', round(v_margin_from_locked, 8),
    'margin_returned_to_wallet', round(v_margin_from_regular, 8),
    'bonus_volume_credited', round(v_bonus_volume, 2), 'real_volume_credited', round(v_real_volume, 2),
    'duration_requirement_met', v_duration_met, 'duration_minutes', round(v_duration_minutes, 1)
  );
END;
$$;
