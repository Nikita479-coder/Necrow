/*
  # Fix Swap Function to Check Available Balance

  ## Description
  Updates the execute_instant_swap function to properly check available balance
  by accounting for locked_balance. This prevents swap orders from being created
  when there's insufficient available balance.

  ## Changes
  - Modified balance check to use (balance - locked_balance) instead of just balance
  - This ensures locked funds are not available for swapping

  ## Impact
  - Prevents failed wallet updates when users try to swap locked funds
  - Ensures swap orders only succeed when there's truly sufficient available balance
*/

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
  
  -- Check sufficient AVAILABLE balance (balance minus locked)
  IF (v_from_wallet.balance - v_from_wallet.locked_balance) < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient available balance. Available: %, Required: %', 
      (v_from_wallet.balance - v_from_wallet.locked_balance), p_from_amount;
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