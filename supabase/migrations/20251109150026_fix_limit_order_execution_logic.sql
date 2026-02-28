/*
  # Fix Limit Order Execution Logic

  ## Description
  Corrects the limit order execution logic:
  - BUY limit orders execute when market price <= limit price (buying at or below target)
  - SELL limit orders execute when market price >= limit price (selling at or above target)

  ## Changes
  - Fixed buy order condition: price >= p_current_price → price <= p_current_price
  - Fixed sell order condition: price <= p_current_price → price >= p_current_price
  - Orders now execute at the correct market conditions
*/

DROP FUNCTION IF EXISTS check_and_execute_limit_orders(text, numeric);

CREATE OR REPLACE FUNCTION check_and_execute_limit_orders(
  p_pair text,
  p_current_price numeric
)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_executed_count int := 0;
  v_result jsonb;
BEGIN
  -- Find and execute matching buy orders (market price <= limit price)
  -- Buy limit: "buy when price drops to X or lower"
  FOR v_order IN
    SELECT order_id, side, price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'long'
    AND p_current_price <= price
    ORDER BY price DESC, created_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN
      v_executed_count := v_executed_count + 1;
    END IF;
  END LOOP;
  
  -- Find and execute matching sell orders (market price >= limit price)
  -- Sell limit: "sell when price rises to X or higher"
  FOR v_order IN
    SELECT order_id, side, price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'short'
    AND p_current_price >= price
    ORDER BY price ASC, created_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN
      v_executed_count := v_executed_count + 1;
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'pair', p_pair,
    'executed_count', v_executed_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;