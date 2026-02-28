/*
  # Fix Exclusive Affiliate Withdrawal Notification Column
  
  ## Problem
  The function uses 'is_read' but the notifications table has column 'read'
  
  ## Solution
  Drop and recreate the function with the correct column name
*/

DROP FUNCTION IF EXISTS request_exclusive_affiliate_withdrawal(uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION request_exclusive_affiliate_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_wallet_address text,
  p_network text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance exclusive_affiliate_balances;
  v_withdrawal_id uuid;
BEGIN
  IF NOT is_exclusive_affiliate(p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enrolled in exclusive affiliate program');
  END IF;
  
  SELECT * INTO v_balance
  FROM exclusive_affiliate_balances
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  IF NOT FOUND OR v_balance.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;
  
  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;
  
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance - p_amount,
    pending_balance = pending_balance + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  INSERT INTO exclusive_affiliate_withdrawals (
    user_id,
    amount,
    currency,
    wallet_address,
    network,
    status
  ) VALUES (
    p_user_id,
    p_amount,
    'USDT',
    p_wallet_address,
    p_network,
    'pending'
  )
  RETURNING id INTO v_withdrawal_id;
  
  -- Fixed: use 'read' instead of 'is_read'
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'withdrawal_submitted',
    'Withdrawal Submitted',
    'Your withdrawal request for $' || p_amount || ' USDT has been submitted and is pending review.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount
  );
END;
$$;
