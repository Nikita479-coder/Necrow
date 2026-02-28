/*
  # Create Limit Swap Order Functionality

  ## Description
  Implements limit swap orders that execute when target price is reached.

  ## Functions

  ### place_limit_swap_order()
  Places a limit order with target price
  - Locks the from_currency balance
  - Creates pending order
  - Sets 30-day expiration
  - Returns order ID

  ### check_and_execute_limit_swap()
  Checks if a specific limit order can be executed
  - Called for individual orders
  - Checks current market price
  - Executes if price target reached

  ### execute_limit_swap_order()
  Internal function to execute a pending limit order
  - Unlocks balance
  - Performs swap
  - Updates order status

  ### cancel_limit_swap_order()
  Allows user to cancel pending limit order
  - Unlocks balance
  - Updates order status

  ## Important Notes
  - Limit orders lock balance until executed or cancelled
  - Orders expire after 30 days
  - Execution happens when: current_rate >= limit_price (for normal orders)
*/

-- Function to place limit swap order
CREATE OR REPLACE FUNCTION place_limit_swap_order(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric,
  p_limit_price numeric
)
RETURNS jsonb AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_order_id uuid;
  v_expected_to_amount numeric;
  v_expires_at timestamptz;
BEGIN
  -- Validate inputs
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  
  IF p_limit_price <= 0 THEN
    RAISE EXCEPTION 'Limit price must be greater than 0';
  END IF;
  
  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;
  
  -- Calculate expected to_amount at limit price
  v_expected_to_amount := p_from_amount * p_limit_price;
  
  -- Set expiration to 30 days from now
  v_expires_at := now() + interval '30 days';
  
  -- Get from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for currency %', p_from_currency;
  END IF;
  
  -- Check sufficient balance
  IF v_from_wallet.balance < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', v_from_wallet.balance, p_from_amount;
  END IF;
  
  -- Lock the balance
  UPDATE wallets
  SET balance = balance - p_from_amount,
      locked_balance = locked_balance + p_from_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = p_from_currency;
  
  -- Ensure to wallet exists
  SELECT * INTO v_to_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_to_currency;
  
  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
    VALUES (p_user_id, p_to_currency, 0, 0, 0, 0);
  END IF;
  
  -- Create limit order
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, limit_price, status, expires_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_expected_to_amount,
    'limit', p_limit_price, 'pending', v_expires_at
  )
  RETURNING order_id INTO v_order_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'from_amount', p_from_amount,
    'expected_to_amount', v_expected_to_amount,
    'limit_price', p_limit_price,
    'expires_at', v_expires_at
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Function to execute a pending limit order
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
  
  -- Record transactions
  INSERT INTO transactions (user_id, type, currency, amount, status, description)
  VALUES 
    (v_order.user_id, 'swap_out', v_order.from_currency, v_order.from_amount, 'completed',
     'Limit swap: ' || v_order.from_amount || ' ' || v_order.from_currency || ' to ' || v_order.to_currency),
    (v_order.user_id, 'swap_in', v_order.to_currency, v_actual_to_amount, 'completed',
     'Limit swap: Received ' || v_actual_to_amount || ' ' || v_order.to_currency);
  
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

-- Function to cancel limit order
CREATE OR REPLACE FUNCTION cancel_limit_swap_order(p_user_id uuid, p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
BEGIN
  -- Get order
  SELECT * INTO v_order
  FROM swap_orders
  WHERE order_id = p_order_id
    AND user_id = p_user_id
    AND status = 'pending'
    AND order_type = 'limit'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found or cannot be cancelled');
  END IF;
  
  -- Unlock balance
  UPDATE wallets
  SET balance = balance + v_order.from_amount,
      locked_balance = locked_balance - v_order.from_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = v_order.from_currency;
  
  -- Update order status
  UPDATE swap_orders
  SET status = 'cancelled', updated_at = now()
  WHERE order_id = p_order_id;
  
  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Function to check all pending limit orders and execute eligible ones
CREATE OR REPLACE FUNCTION check_and_execute_all_limit_swaps()
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_executed_count integer := 0;
  v_expired_count integer := 0;
  v_result jsonb;
BEGIN
  -- Loop through all pending limit orders
  FOR v_order IN
    SELECT order_id FROM swap_orders
    WHERE status = 'pending' AND order_type = 'limit'
  LOOP
    -- Try to execute
    v_result := execute_limit_swap_order(v_order.order_id);
    
    IF (v_result->>'success')::boolean THEN
      v_executed_count := v_executed_count + 1;
    ELSIF v_result->>'error' = 'Order expired' THEN
      v_expired_count := v_expired_count + 1;
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'executed', v_executed_count,
    'expired', v_expired_count
  );
END;
$$ LANGUAGE plpgsql;