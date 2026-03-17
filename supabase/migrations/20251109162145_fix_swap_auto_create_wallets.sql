/*
  # Fix Swap - Auto-create Wallets

  ## Description
  Updates the swap functions to automatically create wallets for currencies
  that don't exist yet. This prevents "Wallet not found" errors.

  ## Changes
  - Modified execute_instant_swap to create from_wallet if it doesn't exist
  - Modified execute_instant_swap to create to_wallet if it doesn't exist
  - Modified place_limit_swap_order to create from_wallet if it doesn't exist
  - Modified place_limit_swap_order to create to_wallet if it doesn't exist

  ## Important
  - New wallets are created with 0 balance
  - Users can only swap currencies they have balance for
  - This allows users to receive any currency without pre-creating wallets
*/

-- Update execute_instant_swap to auto-create wallets
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
  
  -- Get or create from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create from wallet with 0 balance
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
    VALUES (p_user_id, p_from_currency, 0, 0, 0, 0)
    RETURNING * INTO v_from_wallet;
  END IF;
  
  -- Check sufficient balance
  IF v_from_wallet.balance < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', v_from_wallet.balance, p_from_amount;
  END IF;
  
  -- Get or create to wallet
  SELECT * INTO v_to_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_to_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create to wallet
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
    VALUES (p_user_id, p_to_currency, 0, 0, 0, 0)
    RETURNING * INTO v_to_wallet;
  END IF;
  
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
  
  -- Record transaction
  INSERT INTO transactions (user_id, type, currency, amount, status, description)
  VALUES 
    (p_user_id, 'swap_out', p_from_currency, p_from_amount, 'completed', 
     'Swapped ' || p_from_amount || ' ' || p_from_currency || ' to ' || p_to_currency),
    (p_user_id, 'swap_in', p_to_currency, v_to_amount, 'completed',
     'Received ' || v_to_amount || ' ' || p_to_currency || ' from swap');
  
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

-- Update place_limit_swap_order to auto-create wallets
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
  
  -- Get or create from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create from wallet with 0 balance
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
    VALUES (p_user_id, p_from_currency, 0, 0, 0, 0)
    RETURNING * INTO v_from_wallet;
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
  
  -- Ensure to wallet exists (create if needed)
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