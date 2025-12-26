/*
  # Fix Limit Order Execution - Correct Column Names

  ## Description
  Updates the limit order execution functions to use correct column names.
  The table uses 'price' not 'limit_price', and 'average_fill_price' not 'filled_price'.

  ## Changes
  - Uses 'price' column for limit price
  - Uses 'average_fill_price' for filled price
  - Corrected all column references
*/

-- Function to execute a single limit order
DROP FUNCTION IF EXISTS execute_limit_order(uuid);

CREATE OR REPLACE FUNCTION execute_limit_order(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_result jsonb;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  AND order_status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found or already executed');
  END IF;
  
  -- Mark order as filled
  UPDATE futures_orders
  SET order_status = 'filled',
      filled_quantity = quantity,
      remaining_quantity = 0,
      average_fill_price = v_order.price,
      filled_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;
  
  -- Create or update position using existing function
  SELECT create_or_update_position(
    v_order.user_id,
    v_order.pair,
    v_order.side,
    v_order.quantity,
    v_order.price,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount,
    v_order.stop_loss,
    v_order.take_profit
  ) INTO v_result;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'filled_price', v_order.price,
    'position_result', v_result
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and execute all pending limit orders for a pair
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
  -- Find and execute matching buy orders (limit price >= current price)
  FOR v_order IN
    SELECT order_id, side, price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'long'
    AND price >= p_current_price
    ORDER BY price DESC, created_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN
      v_executed_count := v_executed_count + 1;
    END IF;
  END LOOP;
  
  -- Find and execute matching sell orders (limit price <= current price)
  FOR v_order IN
    SELECT order_id, side, price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'short'
    AND price <= p_current_price
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