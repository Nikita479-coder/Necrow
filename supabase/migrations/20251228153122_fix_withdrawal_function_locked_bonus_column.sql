/*
  # Fix Withdrawal Function Locked Bonus Column

  Updates the create_withdrawal_request function to use the correct column name
  'current_amount' instead of 'remaining_amount' for locked bonuses.
  
  Changes:
  - Fixes query to use correct current_amount column
*/

DROP FUNCTION IF EXISTS create_withdrawal_request(uuid, text, numeric, text, text);

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
  v_min_withdraw numeric;
  v_fee numeric;
  v_transaction_id uuid;
  v_locked_bonus numeric := 0;
  v_available_balance numeric := 0;
  v_locked_withdrawal numeric := 0;
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

  -- Get wallet balance for the currency
  SELECT COALESCE(balance, 0) INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = p_currency
    AND wallet_type = 'main';

  -- Get locked bonus if USDT
  IF p_currency = 'USDT' THEN
    SELECT COALESCE(SUM(current_amount), 0) INTO v_locked_bonus
    FROM locked_bonuses
    WHERE user_id = p_user_id AND status = 'active';

    -- Get locked withdrawal balance
    SELECT COALESCE(locked_balance, 0) INTO v_locked_withdrawal
    FROM locked_withdrawal_balances
    WHERE user_id = p_user_id;

    v_available_balance := v_wallet_balance - v_locked_bonus - v_locked_withdrawal;
  ELSE
    v_available_balance := v_wallet_balance;
  END IF;

  -- Set fee and min withdraw based on currency
  CASE p_currency
    WHEN 'USDT' THEN v_fee := 1; v_min_withdraw := 10;
    WHEN 'USDC' THEN v_fee := 1; v_min_withdraw := 10;
    WHEN 'BTC' THEN v_fee := 0.0005; v_min_withdraw := 0.001;
    WHEN 'ETH' THEN v_fee := 0.003; v_min_withdraw := 0.01;
    WHEN 'BNB' THEN v_fee := 0.0001; v_min_withdraw := 0.01;
    WHEN 'SOL' THEN v_fee := 0.01; v_min_withdraw := 0.1;
    WHEN 'XRP' THEN v_fee := 0.1; v_min_withdraw := 10;
    WHEN 'LTC' THEN v_fee := 0.001; v_min_withdraw := 0.01;
    WHEN 'TRX' THEN v_fee := 1; v_min_withdraw := 10;
    WHEN 'DOGE' THEN v_fee := 5; v_min_withdraw := 50;
    WHEN 'ADA' THEN v_fee := 1; v_min_withdraw := 10;
    WHEN 'MATIC' THEN v_fee := 0.1; v_min_withdraw := 1;
    ELSE v_fee := 1; v_min_withdraw := 1;
  END CASE;

  -- Validate minimum withdrawal
  IF p_amount < v_min_withdraw THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Minimum withdrawal is ' || v_min_withdraw || ' ' || p_currency
    );
  END IF;

  -- Check sufficient balance (amount must be available)
  IF p_amount > v_available_balance THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance. Available: ' || v_available_balance || ' ' || p_currency
    );
  END IF;

  -- Deduct from wallet
  UPDATE wallets
  SET balance = balance - p_amount,
      updated_at = now()
  WHERE user_id = p_user_id
    AND currency = p_currency
    AND wallet_type = 'main';

  -- Create transaction record
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
  ) VALUES (
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

  -- Create notification
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'system',
    'Withdrawal Request Submitted',
    'Your withdrawal request for ' || p_amount || ' ' || p_currency || ' has been submitted and is pending review.',
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
    'address', p_address,
    'status', 'pending'
  );
END;
$$;