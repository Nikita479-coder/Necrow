/*
  # Fix Close Position - Use Correct Column Name

  1. Changes
    - Change RETURNING transaction_id to RETURNING id
    - The transactions table uses 'id' as primary key, not 'transaction_id'
*/

CREATE OR REPLACE FUNCTION close_position(
  p_position_id uuid,
  p_close_price numeric DEFAULT NULL,
  p_close_quantity numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_current_price numeric;
  v_gross_pnl numeric;
  v_close_qty numeric;
  v_margin_return numeric;
  v_margin_from_locked numeric;
  v_margin_from_regular numeric;
  v_oldest_bonus_id uuid;
  v_notional_value numeric;
  v_closing_fee numeric;
  v_fee_rate numeric;
  v_net_pnl numeric;
  v_transaction_id uuid;
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

  -- Calculate GROSS PnL (pure price movement, no fees)
  IF v_position.side = 'long' THEN
    v_gross_pnl := (v_current_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_gross_pnl := (v_position.entry_price - v_current_price) * v_close_qty;
  END IF;

  -- Calculate closing fee
  SELECT COALESCE(taker_fee, 0.0004) INTO v_fee_rate
  FROM trading_pairs_config WHERE pair = v_position.pair;

  IF v_fee_rate IS NULL THEN
    v_fee_rate := 0.0004;
  END IF;

  v_notional_value := v_current_price * v_close_qty;
  v_closing_fee := v_notional_value * v_fee_rate;

  -- Net PnL for wallet adjustment (gross - closing fee)
  v_net_pnl := v_gross_pnl - v_closing_fee;

  -- Calculate margin portions to return
  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0);
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0) * (v_close_qty / v_position.quantity);
  END IF;

  v_margin_from_regular := v_margin_return - v_margin_from_locked;

  SELECT id INTO v_oldest_bonus_id FROM locked_bonuses
  WHERE user_id = v_position.user_id
  AND status = 'active'
  AND expires_at > now()
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_margin_from_locked > 0 THEN
    IF v_oldest_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET current_amount = current_amount + v_margin_from_locked,
          updated_at = now()
      WHERE id = v_oldest_bonus_id;
    ELSE
      v_margin_from_regular := v_margin_from_regular + v_margin_from_locked;
      v_margin_from_locked := 0;
    END IF;
  END IF;

  IF v_margin_from_regular > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_margin_from_regular,
        locked_balance = GREATEST(locked_balance - v_margin_return, 0),
        updated_at = now()
    WHERE user_id = v_position.user_id;

    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_margin_from_regular, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_margin_from_regular,
        locked_balance = GREATEST(futures_margin_wallets.locked_balance - v_margin_return, 0),
        updated_at = now();
    END IF;
  ELSE
    UPDATE futures_margin_wallets
    SET locked_balance = GREATEST(locked_balance - v_margin_return, 0),
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;

  -- Apply NET PnL to wallet (includes fee deduction)
  IF v_net_pnl >= 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_net_pnl,
        updated_at = now()
    WHERE user_id = v_position.user_id;

    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_net_pnl, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_net_pnl,
        updated_at = now();
    END IF;

    IF v_oldest_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET realized_profits = realized_profits + v_net_pnl,
          updated_at = now()
      WHERE id = v_oldest_bonus_id;
    END IF;
  ELSE
    PERFORM apply_pnl_to_locked_bonus(v_position.user_id, v_net_pnl);
  END IF;

  -- Create transaction and get ID (use 'id' not 'transaction_id')
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (v_position.user_id, 'futures_close', 'USDT',
          GREATEST(ABS(v_net_pnl), 0.01),
          'completed',
          'Closed ' || v_position.pair || ' ' || upper(v_position.side) || '. Price PnL: ' ||
          CASE WHEN v_gross_pnl >= 0 THEN '+' ELSE '' END || round(v_gross_pnl, 2) ||
          ' USDT (Closing Fee: ' || round(v_closing_fee, 4) || ' USDT)')
  RETURNING id INTO v_transaction_id;

  -- Record closing fee and distribute referral commission
  IF v_closing_fee > 0.0001 THEN
    INSERT INTO fee_collections (
      user_id, position_id, fee_type, fee_amount, notional_size,
      pair, fee_rate, currency
    ) VALUES (
      v_position.user_id, p_position_id, 'futures_close', v_closing_fee, v_notional_value,
      v_position.pair, v_fee_rate, 'USDT'
    );

    -- Pass transaction_id to distribute_trading_fees
    PERFORM distribute_trading_fees(
      v_position.user_id,
      v_transaction_id,
      v_notional_value,
      v_closing_fee,
      v_position.leverage
    );
  END IF;

  -- Update position status - store GROSS PnL (price movement only)
  IF v_close_qty = v_position.quantity THEN
    UPDATE futures_positions
    SET status = 'closed',
        realized_pnl = v_gross_pnl,
        cumulative_fees = cumulative_fees + v_closing_fee,
        mark_price = v_current_price,
        closed_at = now()
    WHERE position_id = p_position_id;
  ELSE
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty,
        margin_allocated = margin_allocated - v_margin_return,
        margin_from_locked_bonus = COALESCE(margin_from_locked_bonus, 0) - v_margin_from_locked,
        cumulative_fees = cumulative_fees + v_closing_fee,
        mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'closed_quantity', v_close_qty,
    'exit_price', v_current_price,
    'pnl', round(v_gross_pnl, 8),
    'closing_fee', round(v_closing_fee, 8),
    'net_pnl', round(v_net_pnl, 8),
    'margin_returned_to_locked_bonus', round(v_margin_from_locked, 8),
    'margin_returned_to_wallet', round(v_margin_from_regular, 8)
  );
END;
$$;
