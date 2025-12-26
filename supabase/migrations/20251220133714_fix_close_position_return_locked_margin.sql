/*
  # Fix Close Position - Return Locked Bonus Margin

  The issue: When closing a position, margin_from_locked_bonus wasn't being returned
  to the locked bonus because apply_pnl_to_locked_bonus only handles losses.

  Fix: Directly update locked_bonuses.current_amount to return the margin.
*/

DROP FUNCTION IF EXISTS public.close_position(uuid, numeric, numeric);

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
  v_margin_from_locked numeric;
  v_margin_from_regular numeric;
  v_net_return numeric;
  v_oldest_bonus_id uuid;
  v_bonus_updated boolean := false;
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

  -- Calculate PnL
  IF v_position.side = 'long' THEN
    v_pnl := (v_current_price - v_position.entry_price) * v_close_qty;
  ELSE
    v_pnl := (v_position.entry_price - v_current_price) * v_close_qty;
  END IF;

  v_trading_fee := (v_current_price * v_close_qty) * 0.0004;

  -- Calculate margin portions
  IF v_close_qty = v_position.quantity THEN
    v_margin_return := v_position.margin_allocated;
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0);
  ELSE
    v_margin_return := v_position.margin_allocated * (v_close_qty / v_position.quantity);
    v_margin_from_locked := COALESCE(v_position.margin_from_locked_bonus, 0) * (v_close_qty / v_position.quantity);
  END IF;
  
  v_margin_from_regular := v_margin_return - v_margin_from_locked;

  -- RETURN MARGIN FROM LOCKED BONUS back to locked bonus (oldest active one)
  IF v_margin_from_locked > 0 THEN
    -- Find the oldest active locked bonus for this user
    SELECT id INTO v_oldest_bonus_id FROM locked_bonuses
    WHERE user_id = v_position.user_id 
      AND status = 'active' 
      AND expires_at > now()
    ORDER BY created_at ASC 
    LIMIT 1;

    IF v_oldest_bonus_id IS NOT NULL THEN
      -- Return margin to locked bonus current_amount
      UPDATE locked_bonuses
      SET current_amount = current_amount + v_margin_from_locked,
          updated_at = now()
      WHERE id = v_oldest_bonus_id;
      
      v_bonus_updated := true;
    ELSE
      -- No active locked bonus, add to regular wallet instead
      v_margin_from_regular := v_margin_from_regular + v_margin_from_locked;
      v_margin_from_locked := 0;
    END IF;
  END IF;

  -- Calculate net return to regular wallet (margin + PnL - fee)
  v_net_return := v_margin_from_regular + v_pnl - v_trading_fee;

  -- Update futures margin wallet with net return
  UPDATE futures_margin_wallets
  SET available_balance = GREATEST(available_balance + v_net_return, 0), 
      updated_at = now()
  WHERE user_id = v_position.user_id;

  IF NOT FOUND THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
    VALUES (v_position.user_id, GREATEST(v_net_return, 0), 0)
    ON CONFLICT (user_id) DO UPDATE SET
      available_balance = GREATEST(futures_margin_wallets.available_balance + v_net_return, 0), 
      updated_at = now();
  END IF;

  -- Track profits in locked bonus
  IF v_pnl > 0 AND v_oldest_bonus_id IS NOT NULL THEN
    UPDATE locked_bonuses 
    SET realized_profits = realized_profits + v_pnl, 
        updated_at = now()
    WHERE id = v_oldest_bonus_id;
  END IF;

  -- Apply losses to locked bonus if there was a loss
  IF v_pnl < 0 THEN
    PERFORM apply_pnl_to_locked_bonus(v_position.user_id, v_pnl);
  END IF;

  -- Update position status
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
        margin_from_locked_bonus = COALESCE(margin_from_locked_bonus, 0) - v_margin_from_locked,
        mark_price = v_current_price
    WHERE position_id = p_position_id;
  END IF;

  -- Record fee collection
  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount, currency)
  VALUES (v_position.user_id, p_position_id, 'taker', v_position.pair, v_current_price * v_close_qty, 0.0004, v_trading_fee, 'USDT');

  -- Record transaction
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (v_position.user_id, 'futures_close', 'USDT', 
    GREATEST(ABS(v_pnl), 0.01),
    'completed',
    'Closed ' || v_position.pair || ' ' || upper(v_position.side) || '. PnL: ' || 
    CASE WHEN v_pnl >= 0 THEN '+' ELSE '' END || round(v_pnl, 2) || ' USDT');

  RETURN jsonb_build_object(
    'success', true, 
    'position_id', p_position_id, 
    'closed_quantity', v_close_qty,
    'exit_price', v_current_price, 
    'pnl', round(v_pnl, 8), 
    'fee', round(v_trading_fee, 8),
    'net_return_to_wallet', round(v_net_return, 8),
    'margin_returned_to_locked_bonus', round(v_margin_from_locked, 8),
    'margin_returned_to_regular', round(v_margin_from_regular, 8),
    'locked_bonus_updated', v_bonus_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_position(uuid, numeric, numeric) TO authenticated;
