/*
  # Fix Execute Limit Order - Handle UUID Return Type

  ## Description
  The create_or_update_position function returns a UUID, not JSONB.
  This fixes the execute_limit_order function to handle the correct return type.

  ## Changes
  - Changed to expect UUID return from create_or_update_position
  - Fixed function to work with actual schema and return types
*/

DROP FUNCTION IF EXISTS execute_limit_order(uuid);

CREATE OR REPLACE FUNCTION execute_limit_order(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_position_id uuid;
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
    v_order.price,
    v_order.quantity,
    v_order.leverage,
    v_order.margin_mode,
    v_order.margin_amount,
    v_order.stop_loss,
    v_order.take_profit
  ) INTO v_position_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'filled_price', v_order.price,
    'position_id', v_position_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;