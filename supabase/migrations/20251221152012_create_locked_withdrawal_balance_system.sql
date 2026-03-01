/*
  # Create Locked Withdrawal Balance System

  ## Summary
  Implements a locked balance system for withdrawals where funds are held in a
  locked state until the admin approves or rejects the withdrawal.

  ## Changes
  1. Add `locked_balance` column to wallets table
     - Stores funds that are pending withdrawal approval
     - Separate from available balance
  
  2. Update `create_withdrawal_request` function
     - Instead of deducting balance, moves funds to locked_balance
     - User cannot spend locked funds
  
  3. Update `admin_process_withdrawal` function
     - On approve/complete: deduct from locked_balance (funds leave the system)
     - On reject: move from locked_balance back to available balance

  4. Create helper function to get available balance
     - Returns balance - locked_balance for accurate available funds

  ## Security
  - Locked funds cannot be spent or withdrawn again
  - Only admin actions can release locked funds
*/

-- Add locked_balance column to wallets if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'wallets' AND column_name = 'locked_balance'
  ) THEN
    ALTER TABLE wallets ADD COLUMN locked_balance numeric(20,8) DEFAULT 0;
  END IF;
END $$;

-- Function to get available balance (balance minus locked)
CREATE OR REPLACE FUNCTION get_available_balance(
  p_user_id uuid,
  p_currency text,
  p_wallet_type text DEFAULT 'main'
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_locked numeric := 0;
BEGIN
  SELECT 
    COALESCE(balance, 0),
    COALESCE(locked_balance, 0)
  INTO v_balance, v_locked
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = p_wallet_type;

  RETURN GREATEST(v_balance - v_locked, 0);
END;
$$;

-- Update create_withdrawal_request to use locked balance
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
  SELECT 
    COALESCE(balance, 0),
    COALESCE(locked_balance, 0)
  INTO v_wallet_balance, v_locked_balance
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';

  -- Get locked trading bonus if USDT
  IF p_currency = 'USDT' THEN
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_locked_bonus
    FROM locked_trading_bonuses
    WHERE user_id = p_user_id AND status = 'active';
  END IF;
  
  -- Calculate available balance (total - locked - trading bonus)
  v_available_balance := v_wallet_balance - v_locked_balance - v_locked_bonus;

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

  -- Check sufficient available balance
  IF p_amount > v_available_balance THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient available balance. Available: ' || ROUND(v_available_balance, 8) || ' ' || p_currency
    );
  END IF;

  -- Lock the funds (add to locked_balance instead of deducting from balance)
  UPDATE wallets
  SET locked_balance = COALESCE(locked_balance, 0) + p_amount,
      updated_at = now()
  WHERE user_id = p_user_id 
    AND currency = p_currency 
    AND wallet_type = 'main';

  -- Create transaction record with pending status
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
$$;

-- Update admin_process_withdrawal to handle locked balance
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

  -- Validate current status for the action
  IF p_action = 'approve' AND v_transaction.status != 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Can only approve pending withdrawals'
    );
  END IF;

  IF p_action = 'complete' AND v_transaction.status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Can only complete pending or processing withdrawals'
    );
  END IF;

  IF p_action = 'reject' AND v_transaction.status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Can only reject pending or processing withdrawals'
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

  -- Handle balance changes based on action
  IF p_action = 'reject' THEN
    -- Unlock the funds back to available balance
    UPDATE wallets
    SET locked_balance = GREATEST(COALESCE(locked_balance, 0) - v_transaction.amount, 0),
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
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been rejected. ' || COALESCE('Reason: ' || p_admin_notes, 'Please contact support for more information.') || ' The funds have been unlocked and are available in your wallet.',
      false
    );
  ELSIF p_action = 'complete' THEN
    -- Deduct from both balance and locked_balance (funds leave the system)
    UPDATE wallets
    SET balance = GREATEST(balance - v_transaction.amount, 0),
        locked_balance = GREATEST(COALESCE(locked_balance, 0) - v_transaction.amount, 0),
        updated_at = now()
    WHERE user_id = v_transaction.user_id 
      AND currency = v_transaction.currency 
      AND wallet_type = 'main';

    -- Create completion notification
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      'system',
      'Withdrawal Completed',
      'Your withdrawal of ' || (v_transaction.amount - v_transaction.fee) || ' ' || v_transaction.currency || ' has been completed and sent to your wallet.' || CASE WHEN p_tx_hash IS NOT NULL THEN ' TX: ' || p_tx_hash ELSE '' END,
      false
    );
  ELSIF p_action = 'approve' THEN
    -- Just update status, funds remain locked
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      'system',
      'Withdrawal Approved',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been approved and is being processed. Your funds remain locked until the transfer is complete.',
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_available_balance(uuid, text, text) TO authenticated;
