/*
  # Fix Swap Functions - Use Positive Amounts

  ## Description
  Updates swap functions to record transactions with positive amounts only,
  since the transactions table has a check constraint requiring amount > 0.

  ## Changes
  - Modified execute_instant_swap to use positive amounts
  - Modified execute_limit_swap_order to use positive amounts
  - Both functions now record two separate transactions (one for each currency)

  ## Important
  - All amounts in transactions table must be positive
  - Transaction direction is indicated by transaction_type and currency
*/

-- Update execute_instant_swap to use positive amounts
CREATE OR REPLACE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_exchange_rate numeric;
  v_to_amount numeric;
  v_order_id uuid;
  v_fee_amount numeric := 0;
BEGIN
  -- Validate inputs
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  
  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;
  
  -- Get current exchange rate
  v_exchange_rate := get_swap_rate(p_from_currency, p_to_currency);
  
  IF v_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'Exchange rate not available for % to %', p_from_currency, p_to_currency;
  END IF;
  
  -- Calculate to_amount
  v_to_amount := p_from_amount * v_exchange_rate;
  
  -- Ensure from wallet exists (create if needed, ignore if exists)
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES (p_user_id, p_from_currency, 0, 0, 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;
  
  -- Get from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;
  
  -- Check sufficient balance
  IF v_from_wallet.balance < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', v_from_wallet.balance, p_from_amount;
  END IF;
  
  -- Ensure to wallet exists (create if needed, ignore if exists)
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES (p_user_id, p_to_currency, 0, 0, 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;
  
  -- Update from wallet (deduct amount)
  UPDATE wallets
  SET balance = balance - p_from_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = p_from_currency;
  
  -- Update to wallet (add amount)
  UPDATE wallets
  SET balance = balance + v_to_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = p_to_currency;
  
  -- Create swap order record
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'instant', v_exchange_rate, 'executed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;
  
  -- Record transactions using positive amounts only
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, fee, confirmed_at)
  VALUES 
    (p_user_id, 'swap', p_from_currency, p_from_amount, 'completed', 0, now()),
    (p_user_id, 'swap', p_to_currency, v_to_amount, 'completed', v_fee_amount, now());
  
  -- Return order details
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'from_amount', p_from_amount,
    'to_amount', v_to_amount,
    'exchange_rate', v_exchange_rate,
    'fee', v_fee_amount
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Update execute_limit_swap_order to use positive amounts
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
  
  -- Record transactions using positive amounts only
  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, fee, confirmed_at)
  VALUES 
    (v_order.user_id, 'swap', v_order.from_currency, v_order.from_amount, 'completed', 0, now()),
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