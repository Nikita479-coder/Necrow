/*
  # Fix Withdrawal Notification Column Name

  Fixes the `create_withdrawal_request` function to use the correct column name `read`
  instead of `is_read` when inserting notifications.

  ## Changes
  - Update create_withdrawal_request function to use correct column name
*/

CREATE OR REPLACE FUNCTION create_withdrawal_request(
  p_user_id uuid,
  p_currency text,
  p_amount numeric,
  p_address text,
  p_network text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_withdrawal_check jsonb;
  v_wallet_balance numeric := 0;
  v_locked_balance numeric := 0;
  v_locked_bonus numeric := 0;
  v_available_balance numeric := 0;
  v_min_withdraw numeric;
  v_fee numeric;
  v_transaction_id uuid;
BEGIN
  -- Check if user is the caller
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Can only create withdrawals for yourself'
    );
  END IF;

  -- Check if withdrawals are allowed
  v_withdrawal_check := check_withdrawal_allowed(p_user_id);
  
  IF NOT (v_withdrawal_check->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_withdrawal_check->>'reason'
    );
  END IF;

  -- Validate address
  IF p_address IS NULL OR length(trim(p_address)) < 10 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid withdrawal address'
    );
  END IF;

  -- Get wallet balance, locked_balance, and locked_bonus for the currency
  SELECT 
    COALESCE(balance, 0),
    COALESCE(locked_balance, 0),
    COALESCE(locked_bonus, 0)
  INTO v_wallet_balance, v_locked_balance, v_locked_bonus
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';
  
  -- Calculate available balance (total - locked_balance - locked_bonus)
  v_available_balance := v_wallet_balance - v_locked_balance - v_locked_bonus;

  IF v_available_balance IS NULL OR v_available_balance <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance for withdrawal'
    );
  END IF;

  -- Get minimum withdraw amount and network fee for currency
  SELECT 
    COALESCE(min_withdraw, 10),
    COALESCE(withdrawal_fee, 1)
  INTO v_min_withdraw, v_fee
  FROM trading_pairs
  WHERE symbol = p_currency
  LIMIT 1;

  -- Check minimum amount
  IF p_amount < v_min_withdraw THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount is below minimum withdrawal: ' || v_min_withdraw || ' ' || p_currency
    );
  END IF;

  -- Check sufficient balance
  IF p_amount > v_available_balance THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. Available: ' || v_available_balance || ' ' || p_currency
    );
  END IF;

  -- Lock the withdrawal amount (move from balance to locked_balance)
  UPDATE wallets
  SET 
    locked_balance = locked_balance + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';

  -- Create withdrawal transaction with pending status
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status,
    address,
    network,
    created_at
  )
  VALUES (
    p_user_id,
    'withdrawal',
    p_currency,
    p_amount,
    v_fee,
    'pending',
    p_address,
    p_network,
    now()
  )
  RETURNING id INTO v_transaction_id;

  -- Create notification (using 'read' instead of 'is_read')
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'system',
    'Withdrawal Request Submitted',
    'Your withdrawal request for ' || p_amount || ' ' || p_currency || ' has been submitted and is pending review. The funds have been locked until processing is complete.',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount,
    'fee', v_fee,
    'receive_amount', p_amount - v_fee,
    'currency', p_currency,
    'network', p_network,
    'status', 'pending'
  );
END;
$$;