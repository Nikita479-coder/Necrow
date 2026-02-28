/*
  # Fix Admin Process Withdrawal - Proper Balance Handling

  1. Problem
    - When withdrawal is created, amount is added to locked_balance
    - When withdrawal is completed, balance and locked_balance were not being deducted
    - When withdrawal is rejected, it was adding to balance instead of releasing locked_balance

  2. Fix
    - On complete: Deduct from both balance AND release locked_balance
    - On reject: Only release from locked_balance (funds stay in balance)

  3. Security
    - Maintains admin-only access
    - Proper logging of all actions
*/

DROP FUNCTION IF EXISTS admin_process_withdrawal(uuid, text, text, text);

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
  v_total_deduction numeric;
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

  -- Handle balance changes based on action
  IF p_action = 'complete' THEN
    -- Calculate total to deduct (amount includes fee that user pays)
    v_total_deduction := v_transaction.amount;
    
    -- Deduct from balance AND release locked_balance
    UPDATE wallets
    SET balance = balance - v_total_deduction,
        locked_balance = GREATEST(0, COALESCE(locked_balance, 0) - v_total_deduction),
        updated_at = now()
    WHERE user_id = v_transaction.user_id 
      AND currency = v_transaction.currency 
      AND wallet_type = 'main';

    -- Create completion notification
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_completed',
      'Withdrawal Completed',
      'Your withdrawal of ' || (v_transaction.amount - v_transaction.fee) || ' ' || v_transaction.currency || ' has been completed.' || CASE WHEN p_tx_hash IS NOT NULL THEN ' TX: ' || p_tx_hash ELSE '' END,
      false
    );

  ELSIF p_action = 'reject' THEN
    -- Only release from locked_balance (funds remain in balance)
    UPDATE wallets
    SET locked_balance = GREATEST(0, COALESCE(locked_balance, 0) - v_transaction.amount),
        updated_at = now()
    WHERE user_id = v_transaction.user_id 
      AND currency = v_transaction.currency 
      AND wallet_type = 'main';

    -- Create rejection notification
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_rejected',
      'Withdrawal Rejected',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been rejected. ' || COALESCE('Reason: ' || p_admin_notes, 'Please contact support for more information.') || ' The funds remain available in your wallet.',
      false
    );

  ELSIF p_action = 'approve' THEN
    -- Just notification for approval, no balance changes yet
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_approved',
      'Withdrawal Approved',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been approved and is being processed.',
      false
    );
  END IF;

  -- Log admin action
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    target_user_id,
    metadata
  ) VALUES (
    v_admin_id,
    'process_withdrawal_' || p_action,
    'Processed withdrawal ' || p_action || ' for transaction ' || p_transaction_id,
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
