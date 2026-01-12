/*
  # Fix liquidate_position Function

  1. Problem
    - Uses `metadata` instead of `details` for transactions table

  2. Fix
    - Change transaction insert to use `details` column
*/

CREATE OR REPLACE FUNCTION liquidate_position(p_position_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_liquidation_fee numeric;
  v_notional_value numeric;
  v_insurance_fund_amount numeric;
  v_exchange_amount numeric;
BEGIN
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  v_notional_value := v_position.mark_price * v_position.quantity;

  v_liquidation_fee := v_notional_value * 0.005;
  v_insurance_fund_amount := v_liquidation_fee * 0.5;
  v_exchange_amount := v_liquidation_fee * 0.5;

  UPDATE futures_positions
  SET 
    status = 'liquidated',
    realized_pnl = -v_position.margin_allocated,
    cumulative_fees = cumulative_fees + v_liquidation_fee,
    closed_at = NOW(),
    last_price_update = NOW()
  WHERE position_id = p_position_id;

  INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount)
  VALUES (v_position.user_id, p_position_id, 'liquidation', v_position.pair, v_notional_value, 0.005, v_liquidation_fee);

  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, details)
  VALUES (
    v_position.user_id, 
    'liquidation', 
    -v_position.margin_allocated, 
    'USDT', 
    'completed',
    format('Liquidated %s %s position. Fee: %s USDT', 
      v_position.pair, UPPER(v_position.side), ROUND(v_liquidation_fee, 2))
  );

  INSERT INTO notifications (user_id, type, title, message, data, read)
  VALUES (
    v_position.user_id, 
    'liquidation', 
    'Position Liquidated',
    'Your ' || v_position.pair || ' ' || UPPER(v_position.side) || ' position has been liquidated.',
    jsonb_build_object('position_id', p_position_id, 'pair', v_position.pair, 'margin_lost', v_position.margin_allocated),
    false
  );

  PERFORM distribute_multi_tier_commissions(
    p_trader_id := v_position.user_id,
    p_trade_amount := v_notional_value,
    p_fee_amount := v_liquidation_fee,
    p_trade_id := p_position_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'position_id', p_position_id,
    'margin_lost', v_position.margin_allocated,
    'liquidation_fee', v_liquidation_fee
  );
END;
$$;
