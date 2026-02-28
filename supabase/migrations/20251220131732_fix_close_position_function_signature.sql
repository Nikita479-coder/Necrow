/*
  # Fix close_position function signature
  
  The frontend expects parameters: (p_position_id, p_close_quantity, p_close_price)
  The current function only has: (p_position_id, p_close_price)
  
  This migration updates the function to match the expected signature.
*/

DROP FUNCTION IF EXISTS public.close_position(uuid, numeric);

CREATE OR REPLACE FUNCTION public.close_position(
  p_position_id uuid,
  p_close_quantity numeric DEFAULT NULL,
  p_close_price numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_position record;
  v_current_price numeric;
  v_pnl numeric;
  v_close_qty numeric;
  v_margin_return numeric;
  v_trading_fee numeric;
  v_return_amount numeric;
  v_locked_bonus_balance numeric;
  v_loss_from_locked numeric := 0;
  v_loss_from_regular numeric := 0;
  v_oldest_locked_bonus_id uuid;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  IF p_close_price IS NOT NULL AND p_close_price > 0 THEN
    v_current_price := p_close_price;
  ELSE
    SELECT last_price INTO v_current_price
    FROM market_prices
    WHERE pair = v_position.pair;
    
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

  v_trading_fee := (v_current_price * v_close_qty) * 0.0004;

  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
  END IF;

  v_return_amount := v_margin_return + v_pnl - v_trading_fee;

  IF v_pnl < 0 THEN
    v_locked_bonus_balance := COALESCE(get_user_locked_bonus_balance(v_position.user_id), 0);
    
    IF v_locked_bonus_balance > 0 THEN
      v_loss_from_locked := LEAST(v_locked_bonus_balance, ABS(v_pnl));
      PERFORM apply_pnl_to_locked_bonus(v_position.user_id, -v_loss_from_locked);
      v_loss_from_regular := ABS(v_pnl) - v_loss_from_locked;
    ELSE
      v_loss_from_regular := ABS(v_pnl);
    END IF;
    
    v_return_amount := v_margin_return - v_loss_from_regular - v_trading_fee;
  END IF;

  IF v_close_qty = v_position.quantity THEN
    UPDATE futures_positions
    SET status = 'closed',
        realized_pnl = v_pnl,
        mark_price = v_current_price,
        cumulative_fees = COALESCE(cumulative_fees, 0) + v_trading_fee,
        closed_at = now()
    WHERE position_id = p_position_id;
  ELSE
    UPDATE futures_positions
    SET quantity = quantity - v_close_qty,
        margin_allocated = margin_allocated - v_margin_return,
        mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  IF v_return_amount > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_return_amount,
        updated_at = now()
    WHERE user_id = v_position.user_id;
    
    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (v_position.user_id, v_return_amount, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance + v_return_amount,
        updated_at = now();
    END IF;
  END IF;

  INSERT INTO fee_collections (
    user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency
  ) VALUES (
    v_position.user_id, p_position_id, 'taker', v_position.pair, 
    v_current_price * v_close_qty, 0.0004, v_trading_fee, 'USDT'
  );

  INSERT INTO transactions (
    user_id, transaction_type, currency, amount, status, details
  ) VALUES (
    v_position.user_id, 'futures_close', 'USDT', v_return_amount, 'completed',
    'Closed ' || v_position.pair || ' ' || upper(v_position.side) || ' position. PnL: ' || round(v_pnl, 2) || ' USDT'
  );

  IF v_pnl > 0 THEN
    SELECT id INTO v_oldest_locked_bonus_id
    FROM locked_bonuses
    WHERE user_id = v_position.user_id 
      AND status = 'active'
      AND expires_at > now()
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_oldest_locked_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET realized_profits = realized_profits + v_pnl,
          updated_at = now()
      WHERE id = v_oldest_locked_bonus_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'closed_quantity', v_close_qty,
    'exit_price', v_current_price,
    'pnl', round(v_pnl, 8),
    'fee', round(v_trading_fee, 8),
    'return_amount', round(v_return_amount, 8),
    'loss_from_locked_bonus', round(v_loss_from_locked, 8)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_position(uuid, numeric, numeric) TO authenticated;
