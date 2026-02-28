/*
  # Limit Order Execution System

  ## Description
  Implements automatic execution of pending limit orders when market price reaches the limit price.
  This system monitors price updates and executes matching orders.

  ## Functions Created
  1. check_and_execute_limit_orders() - Checks pending orders against current price
  2. execute_limit_order() - Executes a single limit order
  3. Trigger on market_prices to auto-execute orders on price updates

  ## How It Works
  - When market price updates, trigger checks all pending limit orders
  - Buy orders execute when market price <= limit price
  - Sell orders execute when market price >= limit price
  - Orders are filled at their limit price
  - Position is created/updated just like market orders
*/

-- Function to execute a single limit order
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
      filled_price = v_order.limit_price,
      filled_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;
  
  -- Create or update position using existing function
  SELECT create_or_update_position(
    v_order.user_id,
    v_order.pair,
    v_order.side,
    v_order.quantity,
    v_order.limit_price,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount,
    v_order.stop_loss,
    v_order.take_profit
  ) INTO v_result;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'filled_price', v_order.limit_price,
    'position_result', v_result
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and execute all pending limit orders for a pair
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
    SELECT order_id, side, limit_price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'long'
    AND limit_price >= p_current_price
    ORDER BY limit_price DESC, created_at ASC
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN
      v_executed_count := v_executed_count + 1;
    END IF;
  END LOOP;
  
  -- Find and execute matching sell orders (limit price <= current price)
  FOR v_order IN
    SELECT order_id, side, limit_price
    FROM futures_orders
    WHERE pair = p_pair
    AND order_status = 'pending'
    AND order_type = 'limit'
    AND side = 'short'
    AND limit_price <= p_current_price
    ORDER BY limit_price ASC, created_at ASC
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

-- Create a function that is called when market prices are updated
CREATE OR REPLACE FUNCTION trigger_limit_order_execution()
RETURNS trigger AS $$
BEGIN
  -- Execute limit orders for this pair at the new price
  PERFORM check_and_execute_limit_orders(NEW.pair, NEW.mark_price);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on market_prices table
DROP TRIGGER IF EXISTS execute_limit_orders_on_price_update ON market_prices;
CREATE TRIGGER execute_limit_orders_on_price_update
  AFTER INSERT OR UPDATE OF mark_price
  ON market_prices
  FOR EACH ROW
  EXECUTE FUNCTION trigger_limit_order_execution();