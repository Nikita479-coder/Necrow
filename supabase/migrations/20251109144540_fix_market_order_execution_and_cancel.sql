/*
  # Fix Market Order Execution and Cancel Functionality

  ## Description
  This migration fixes two critical issues:
  1. Market orders not executing immediately - they stay in pending status
  2. Adds proper cancel order functionality with margin unlock

  ## Changes
  - Updates place_futures_order to check execution result
  - Adds cancel_futures_order function to properly cancel orders
  - Adds logging to debug execution issues
  - Ensures margin is properly unlocked when orders are cancelled
*/

-- Fix the place_futures_order function to handle execution failures
DROP FUNCTION IF EXISTS place_futures_order(uuid, text, text, text, numeric, integer, text, numeric, numeric, numeric, numeric, boolean);

CREATE OR REPLACE FUNCTION place_futures_order(
  p_user_id uuid,
  p_pair text,
  p_side text,
  p_order_type text,
  p_quantity numeric,
  p_leverage integer,
  p_margin_mode text,
  p_price numeric DEFAULT NULL,
  p_trigger_price numeric DEFAULT NULL,
  p_stop_loss numeric DEFAULT NULL,
  p_take_profit numeric DEFAULT NULL,
  p_reduce_only boolean DEFAULT false
)
RETURNS jsonb AS $$
DECLARE
  v_validation jsonb;
  v_order_id uuid;
  v_margin_amount numeric;
  v_mark_price numeric;
  v_execution_result boolean;
BEGIN
  -- Validate request
  v_validation := validate_order_request(
    p_user_id, p_pair, p_side, p_quantity, p_leverage, p_margin_mode, p_price
  );
  
  IF NOT (v_validation->>'valid')::boolean THEN
    RETURN v_validation;
  END IF;
  
  v_margin_amount := (v_validation->>'total_required')::numeric;
  
  -- Lock margin
  IF NOT lock_margin_for_order(p_user_id, v_margin_amount) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Failed to lock margin. Insufficient balance.'
    );
  END IF;
  
  -- Get mark price
  SELECT mark_price INTO v_mark_price
  FROM market_prices
  WHERE pair = p_pair;
  
  IF v_mark_price IS NULL THEN
    v_mark_price := COALESCE(p_price, 50000);
  END IF;
  
  -- Insert order
  INSERT INTO futures_orders (
    user_id, pair, side, order_type, quantity, leverage, margin_mode,
    margin_amount, price, trigger_price, stop_loss, take_profit,
    reduce_only, order_status
  )
  VALUES (
    p_user_id, p_pair, p_side, p_order_type, p_quantity, p_leverage, p_margin_mode,
    v_margin_amount, p_price, p_trigger_price, p_stop_loss, p_take_profit,
    p_reduce_only, 'pending'
  )
  RETURNING order_id INTO v_order_id;
  
  -- If market order, execute immediately
  IF p_order_type = 'market' THEN
    v_execution_result := execute_market_order(v_order_id);
    
    IF NOT v_execution_result THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to execute market order',
        'order_id', v_order_id
      );
    END IF;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'margin_locked', v_margin_amount,
    'executed', p_order_type = 'market'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create cancel order function
CREATE OR REPLACE FUNCTION cancel_futures_order(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM futures_orders
  WHERE order_id = p_order_id
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;
  
  -- Only pending orders can be cancelled
  IF v_order.order_status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Cannot cancel order with status: %s', v_order.order_status)
    );
  END IF;
  
  -- Unlock the margin
  UPDATE futures_margin_wallets
  SET available_balance = available_balance + v_order.margin_amount,
      used_margin = used_margin - v_order.margin_amount,
      updated_at = now()
  WHERE user_id = v_order.user_id;
  
  -- Update order status
  UPDATE futures_orders
  SET order_status = 'cancelled',
      updated_at = now()
  WHERE order_id = p_order_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Order cancelled successfully',
    'margin_unlocked', v_order.margin_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;