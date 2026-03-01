/*
  # Double the Closing Fee Rate

  Updates the closing fee calculation to use 2x the standard fee rate.
  This applies 0.08% fee on margin instead of 0.04%.
*/

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
BEGIN
  -- Get and lock position
  SELECT * INTO v_position FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open' FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  -- Get closing price
  IF p_close_price IS NOT NULL AND p_close_price > 0 THEN
    v_current_price := p_close_price;
  ELSE
    SELECT last_price INTO v_current_price FROM market_prices WHERE pair = v_position.pair;
    IF v_current_price IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Could not get market price');
    END IF;
  END IF;

  -- Determine close quantity
  IF p_close_quantity IS NOT NULL AND p_close_quantity > 0 THEN
    v_close_qty := LEAST(p_close_quantity, v_position.quantity);
  ELSE
    v_close_qty := v_position.quantity;
  END IF;

  -- Calculate PnL (before fees)
  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_close_qty;
  END IF;

  -- Get fee rate and DOUBLE it for closing
  SELECT COALESCE(taker_fee, 0.0004) INTO v_fee_rate 
  FROM trading_pairs_config WHERE pair = v_position.pair;
  IF v_fee_rate IS NULL THEN
    v_fee_rate := 0.0004;
  END IF;
  
  -- Double the fee rate for closing
  v_fee_rate := v_fee_rate * 2;

  -- Calculate margin return
  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0);
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0) * (v_close_qty / v_position.quantity);
  END IF;

  v_margin_from_regular := v_margin_return - v_margin_from_locked;

  -- Calculate closing fee based on MARGIN with doubled rate
  v_closing_fee := v_margin_return * v_fee_rate;
  v_net_pnl := v_pnl - v_closing_fee;

  -- Get oldest active bonus for returning locked margin
  SELECT id INTO v_oldest_bonus_id FROM locked_bonuses
  WHERE user_id = v_position.user_id 
    AND status = 'active' 
    AND expires_at > now()
  ORDER BY created_at ASC 
  LIMIT 1;

  -- Return locked margin to bonus or wallet
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

  -- Return regular margin to futures wallet
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

  -- Handle PnL (after fee deduction)
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

  -- Create transaction record FIRST
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (v_position.user_id, 'futures_close', 'USDT', 
    GREATEST(ABS(v_net_pnl), 0.01),
    'completed',
    'Closed ' || v_position.pair || ' ' || upper(v_position.side) || '. PnL: ' || 
    CASE WHEN v_net_pnl >= 0 THEN '+' ELSE '' END || round(v_net_pnl, 2) || ' USDT (Fee: ' || round(v_closing_fee, 4) || ')')
  RETURNING id INTO v_transaction_id;

  -- Record closing fee (store margin as notional_size for tracking)
  v_notional_value := v_current_price * v_close_qty;
  IF v_closing_fee > 0.0001 THEN
    INSERT INTO fee_collections (
      user_id, position_id, fee_type, fee_amount, notional_size, 
      pair, fee_rate, currency
    ) VALUES (
      v_position.user_id, p_position_id, 'futures_close', v_closing_fee, v_margin_return,
      v_position.pair, v_fee_rate, 'USDT'
    );
  END IF;

  -- Update or close position
  IF v_close_qty = v_position.quantity THEN
    UPDATE futures_positions
    SET status = 'closed', 
        realized_pnl = v_net_pnl, 
        mark_price = v_current_price,
        closed_at = now()
    WHERE position_id = p_position_id;
  ELSE
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty, 
        margin_allocated = margin_allocated - v_margin_return,
        margin_from_locked_bonus = COALESCE(margin_from_locked_bonus, 0) - v_margin_from_locked,
        mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 
    'position_id', p_position_id, 
    'closed_quantity', v_close_qty,
    'exit_price', v_current_price, 
    'pnl', round(v_pnl, 8),
    'closing_fee', round(v_closing_fee, 8),
    'net_pnl', round(v_net_pnl, 8),
    'margin_returned_to_locked_bonus', round(v_margin_from_locked, 8),
    'margin_returned_to_wallet', round(v_margin_from_regular, 8)
  );
END;
$$;