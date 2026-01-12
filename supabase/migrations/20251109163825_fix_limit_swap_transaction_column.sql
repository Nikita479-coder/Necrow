/*
  # Fix Limit Swap - Correct Transaction Column Name

  ## Description
  Updates execute_limit_swap_order function to use the correct column name 
  "transaction_type" instead of "type" when inserting into transactions table.

  ## Changes
  - Modified execute_limit_swap_order to use transaction_type column
  - Removes description column which doesn't exist
  - Uses correct schema: transaction_type, currency, amount, status, fee, confirmed_at

  ## Important
  - Fixes "column type does not exist" error in limit swap orders
*/

-- Update execute_limit_swap_order with correct transaction column names
CREATE OR REPLACE FUNCTION execute_limit_swap_order(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_current_rate numeric;
  v_actual_to_amount numeric;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM swap_orders
  WHERE order_id = p_order_id
  AND status = 'pending'
  AND order_type = 'limit'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found or not pending');
  END IF;
  
  -- Check if expired
  IF v_order.expires_at < now() THEN
    -- Mark as expired and unlock balance
    UPDATE swap_orders
    SET status = 'expired', updated_at = now()
    WHERE order_id = p_order_id;
    
    UPDATE wallets
    SET balance = balance + v_order.from_amount,
        locked_balance = locked_balance - v_order.from_amount,
        updated_at = now()
    WHERE user_id = v_order.user_id AND currency = v_order.from_currency;
    
    RETURN jsonb_build_object('success', false, 'error', 'Order expired');
  END IF;
  
  -- Get current exchange rate
  v_current_rate := get_swap_rate(v_order.from_currency, v_order.to_currency);
  
  IF v_current_rate <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Exchange rate not available');
  END IF;
  
  -- Check if limit price reached
  IF v_current_rate < v_order.limit_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Limit price not reached', 'current_rate', v_current_rate, 'limit_price', v_order.limit_price);
  END IF;
  
  -- Execute swap at current rate
  v_actual_to_amount := v_order.from_amount * v_current_rate;
  
  -- Unlock from balance (it was already deducted when order was placed)
  UPDATE wallets
  SET locked_balance = locked_balance - v_order.from_amount,
      updated_at = now()
  WHERE user_id = v_order.user_id AND currency = v_order.from_currency;
  
  -- Add to balance
  UPDATE wallets
  SET balance = balance + v_actual_to_amount,
      updated_at = now()
  WHERE user_id = v_order.user_id AND currency = v_order.to_currency;
  
  -- Update order
  UPDATE swap_orders
  SET status = 'executed',
      execution_rate = v_current_rate,
      to_amount = v_actual_to_amount,
      executed_at = now(),
      updated_at = now()
  WHERE order_id = p_order_id;
  
  -- Record transactions using correct column names
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, fee, confirmed_at)
  VALUES 
    (v_order.user_id, 'swap', v_order.from_currency, -v_order.from_amount, 'completed', 0, now()),
    (v_order.user_id, 'swap', v_order.to_currency, v_actual_to_amount, 'completed', 0, now());
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'from_amount', v_order.from_amount,
    'to_amount', v_actual_to_amount,
    'execution_rate', v_current_rate
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;