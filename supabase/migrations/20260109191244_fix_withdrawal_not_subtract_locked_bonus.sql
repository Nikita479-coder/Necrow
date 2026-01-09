/*
  # Fix Withdrawal Request - Don't Subtract Locked Bonus

  The locked trading bonus is completely separate from wallet balance.
  Users should be able to withdraw their full wallet balance regardless
  of any locked trading bonuses they have.
  
  The locked bonus:
  - Is only for trading purposes
  - Cannot be withdrawn directly
  - Does NOT reduce withdrawable funds
  
  Changes:
  - Remove locked bonus subtraction from available balance calculation
*/

CREATE OR REPLACE FUNCTION public.create_withdrawal_request(
  p_user_id uuid, 
  p_currency text, 
  p_amount numeric, 
  p_address text, 
  p_network text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_withdrawal_check jsonb;
  v_wallet_balance numeric := 0;
  v_locked_balance numeric := 0;
  v_min_withdraw numeric;
  v_fee numeric;
  v_transaction_id uuid;
  v_available_balance numeric := 0;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Can only create withdrawals for yourself'
    );
  END IF;

  v_withdrawal_check := check_withdrawal_allowed(p_user_id);

  IF NOT (v_withdrawal_check->>'allowed')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_withdrawal_check->>'reason'
    );
  END IF;

  IF p_address IS NULL OR length(trim(p_address)) < 10 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid withdrawal address'
    );
  END IF;

  SELECT 
    COALESCE(balance, 0),
    COALESCE(locked_balance, 0)
  INTO v_wallet_balance, v_locked_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';

  -- Available balance is wallet balance minus any locked balance (pending withdrawals)
  -- Note: Locked trading bonuses are SEPARATE and do NOT reduce withdrawable funds
  v_available_balance := v_wallet_balance - v_locked_balance;

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

  IF p_amount < v_min_withdraw THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Minimum withdrawal is ' || v_min_withdraw || ' ' || p_currency
    );
  END IF;

  IF p_amount > v_available_balance THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. Available: ' || ROUND(v_available_balance, 8) || ' ' || p_currency
    );
  END IF;

  UPDATE wallets
  SET locked_balance = COALESCE(locked_balance, 0) + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';

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
    'address', p_address,
    'status', 'pending',
    'message', 'Funds have been locked pending approval'
  );
END;
$function$;
