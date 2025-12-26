/*
  # Create Withdrawal Request System

  ## Summary
  Creates a complete withdrawal request system with functions for users to submit
  withdrawal requests and admins to process them.

  ## New Functions
  1. `create_withdrawal_request` - User function to submit a withdrawal
     - Validates user can withdraw (not blocked)
     - Validates balance sufficiency
     - Validates minimum withdrawal amount
     - Deducts from user wallet
     - Creates transaction record with 'pending' status
     - Returns success/error response

  2. `admin_process_withdrawal` - Admin function to approve/reject withdrawals
     - Only admins can call
     - Updates transaction status
     - If rejected, refunds the user
     - Creates notification for user
     - Logs the action

  3. `admin_get_all_withdrawals` - Admin function to list all withdrawals
     - Returns withdrawals with user details
     - Supports filtering by status
     - Supports pagination

  ## Security
  - Users can only create withdrawals for themselves
  - Only admins can process withdrawals
  - All actions are logged
*/

-- Function to create a withdrawal request
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
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_locked_bonus
    FROM locked_trading_bonuses
    WHERE user_id = p_user_id AND status = 'active';
    
    v_available_balance := v_wallet_balance - v_locked_bonus;
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
  INSERT INTO notifications (user_id, type, title, message, is_read)
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

-- Function to process (approve/reject) a withdrawal
CREATE OR REPLACE FUNCTION admin_process_withdrawal(
  p_transaction_id uuid,
  p_action text,
  p_tx_hash text DEFAULT NULL,
  p_admin_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_transaction record;
  v_new_status text;
BEGIN
  -- Check if caller is admin
  IF NOT is_user_admin(v_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Validate action
  IF p_action NOT IN ('approve', 'reject', 'complete') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid action. Must be approve, reject, or complete'
    );
  END IF;

  -- Get transaction details
  SELECT * INTO v_transaction
  FROM transactions
  WHERE id = p_transaction_id AND transaction_type = 'withdrawal';

  IF v_transaction IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Withdrawal not found'
    );
  END IF;

  -- Determine new status
  CASE p_action
    WHEN 'approve' THEN v_new_status := 'processing';
    WHEN 'complete' THEN v_new_status := 'completed';
    WHEN 'reject' THEN v_new_status := 'failed';
  END CASE;

  -- Update transaction
  UPDATE transactions
  SET status = v_new_status,
      tx_hash = COALESCE(p_tx_hash, tx_hash),
      confirmed_at = CASE WHEN p_action = 'complete' THEN now() ELSE confirmed_at END,
      updated_at = now()
  WHERE id = p_transaction_id;

  -- If rejected, refund the user
  IF p_action = 'reject' THEN
    UPDATE wallets
    SET balance = balance + v_transaction.amount,
        updated_at = now()
    WHERE user_id = v_transaction.user_id 
      AND currency = v_transaction.currency 
      AND wallet_type = 'main';

    -- Create refund notification
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      'system',
      'Withdrawal Rejected',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been rejected. ' || COALESCE('Reason: ' || p_admin_notes, 'Please contact support for more information.') || ' The funds have been returned to your wallet.',
      false
    );
  ELSIF p_action = 'approve' THEN
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      'system',
      'Withdrawal Approved',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been approved and is being processed.',
      false
    );
  ELSIF p_action = 'complete' THEN
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      'system',
      'Withdrawal Completed',
      'Your withdrawal of ' || (v_transaction.amount - v_transaction.fee) || ' ' || v_transaction.currency || ' has been completed.' || CASE WHEN p_tx_hash IS NOT NULL THEN ' TX: ' || p_tx_hash ELSE '' END,
      false
    );
  END IF;

  -- Log admin action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    v_admin_id,
    'process_withdrawal_' || p_action,
    v_transaction.user_id,
    jsonb_build_object(
      'transaction_id', p_transaction_id,
      'amount', v_transaction.amount,
      'currency', v_transaction.currency,
      'action', p_action,
      'tx_hash', p_tx_hash,
      'notes', p_admin_notes
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Withdrawal ' || p_action || 'd successfully',
    'new_status', v_new_status
  );
END;
$$;

-- Function to get all withdrawals for admin
CREATE OR REPLACE FUNCTION admin_get_all_withdrawals(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_withdrawals jsonb;
  v_total_count int;
BEGIN
  -- Check if caller is admin
  IF NOT is_user_admin(v_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get total count
  SELECT COUNT(*) INTO v_total_count
  FROM transactions t
  WHERE t.transaction_type = 'withdrawal'
    AND (p_status IS NULL OR t.status = p_status);

  -- Get withdrawals with user info
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'user_id', t.user_id,
      'email', u.email,
      'username', up.username,
      'full_name', up.full_name,
      'currency', t.currency,
      'amount', t.amount,
      'fee', t.fee,
      'receive_amount', t.amount - t.fee,
      'status', t.status,
      'address', t.address,
      'network', t.network,
      'tx_hash', t.tx_hash,
      'created_at', t.created_at,
      'updated_at', t.updated_at,
      'confirmed_at', t.confirmed_at
    ) ORDER BY t.created_at DESC
  ) INTO v_withdrawals
  FROM transactions t
  JOIN auth.users u ON u.id = t.user_id
  LEFT JOIN user_profiles up ON up.id = t.user_id
  WHERE t.transaction_type = 'withdrawal'
    AND (p_status IS NULL OR t.status = p_status)
  LIMIT p_limit
  OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'withdrawals', COALESCE(v_withdrawals, '[]'::jsonb),
    'total', v_total_count,
    'limit', p_limit,
    'offset', p_offset
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_withdrawal_request(uuid, text, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_withdrawal(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_all_withdrawals(text, int, int) TO authenticated;
