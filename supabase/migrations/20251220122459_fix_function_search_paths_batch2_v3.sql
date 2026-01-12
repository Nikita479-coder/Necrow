/*
  # Fix Function Search Paths - Batch 2

  ## Description
  Adding SET search_path = public to SECURITY DEFINER functions.
  Using DROP and CREATE for functions with signature changes.
*/

-- Fix cancel_futures_order
CREATE OR REPLACE FUNCTION cancel_futures_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM futures_orders WHERE order_id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;
  IF v_order.order_status != 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', format('Cannot cancel order with status: %s', v_order.order_status));
  END IF;
  UPDATE futures_margin_wallets
  SET available_balance = available_balance + v_order.margin_amount,
      locked_balance = locked_balance - v_order.margin_amount,
      updated_at = now()
  WHERE user_id = v_order.user_id;
  UPDATE futures_orders SET order_status = 'cancelled', updated_at = now() WHERE order_id = p_order_id;
  RETURN jsonb_build_object('success', true, 'message', 'Order cancelled successfully', 'margin_unlocked', v_order.margin_amount);
END;
$$;

-- Fix check_and_execute_limit_orders
CREATE OR REPLACE FUNCTION check_and_execute_limit_orders(p_pair text, p_current_price numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_executed_count int := 0;
  v_result jsonb;
BEGIN
  FOR v_order IN
    SELECT order_id, side, price FROM futures_orders
    WHERE pair = p_pair AND order_status = 'pending' AND order_type = 'limit'
      AND side = 'long' AND p_current_price <= price
    ORDER BY price DESC, created_at ASC FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN v_executed_count := v_executed_count + 1; END IF;
  END LOOP;

  FOR v_order IN
    SELECT order_id, side, price FROM futures_orders
    WHERE pair = p_pair AND order_status = 'pending' AND order_type = 'limit'
      AND side = 'short' AND p_current_price >= price
    ORDER BY price ASC, created_at ASC FOR UPDATE SKIP LOCKED
  LOOP
    SELECT execute_limit_order(v_order.order_id) INTO v_result;
    IF (v_result->>'success')::boolean THEN v_executed_count := v_executed_count + 1; END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'pair', p_pair, 'executed_count', v_executed_count);
END;
$$;

-- Fix execute_limit_order
CREATE OR REPLACE FUNCTION execute_limit_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_position_id uuid;
BEGIN
  SELECT * INTO v_order FROM futures_orders WHERE order_id = p_order_id AND order_status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found or already executed');
  END IF;
  UPDATE futures_orders
  SET order_status = 'filled', filled_quantity = quantity, remaining_quantity = 0,
      average_fill_price = v_order.price, filled_at = now(), updated_at = now()
  WHERE order_id = p_order_id;
  SELECT create_or_update_position(v_order.user_id, v_order.pair, v_order.side, v_order.price, v_order.quantity,
    v_order.leverage, v_order.margin_mode, v_order.margin_amount, v_order.stop_loss, v_order.take_profit) INTO v_position_id;
  RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'filled_price', v_order.price, 'position_id', v_position_id);
END;
$$;

-- Fix promote_user_to_admin
CREATE OR REPLACE FUNCTION promote_user_to_admin(target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE user_profiles SET is_admin = true WHERE id = target_user_id;
  RETURN jsonb_build_object('success', true, 'message', 'User promoted to admin');
END;
$$;

-- Fix trigger_update_vip_after_transaction
CREATE OR REPLACE FUNCTION trigger_update_vip_after_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM update_user_vip_level(NEW.user_id);
  RETURN NEW;
END;
$$;

-- Fix update_all_vip_levels
CREATE OR REPLACE FUNCTION update_all_vip_levels()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN SELECT id FROM user_profiles LOOP
    PERFORM update_user_vip_level(v_user_id);
  END LOOP;
END;
$$;
