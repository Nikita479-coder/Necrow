/*
  # Update Withdrawal Processing with Proper Notification Types

  ## Summary
  Updates the admin_process_withdrawal function to use proper notification types
  instead of generic 'system' type.

  ## Changes
  - Uses withdrawal_approved type when withdrawal is approved
  - Uses withdrawal_completed type when withdrawal is completed
  - Uses withdrawal_rejected type when withdrawal is rejected

  ## Security
  - Function remains SECURITY DEFINER for admin use
*/

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
  v_notification_type text;
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

  -- Determine new status and notification type
  CASE p_action
    WHEN 'approve' THEN 
      v_new_status := 'processing';
      v_notification_type := 'withdrawal_approved';
    WHEN 'complete' THEN 
      v_new_status := 'completed';
      v_notification_type := 'withdrawal_completed';
    WHEN 'reject' THEN 
      v_new_status := 'failed';
      v_notification_type := 'withdrawal_rejected';
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
      v_notification_type,
      'Withdrawal Rejected',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been rejected. ' || COALESCE('Reason: ' || p_admin_notes, 'Please contact support for more information.') || ' The funds have been returned to your wallet.',
      false
    );
  ELSIF p_action = 'approve' THEN
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      v_notification_type,
      'Withdrawal Approved',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been approved and is being processed.',
      false
    );
  ELSIF p_action = 'complete' THEN
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_transaction.user_id,
      v_notification_type,
      'Withdrawal Completed',
      'Your withdrawal of ' || (v_transaction.amount - COALESCE(v_transaction.fee, 0)) || ' ' || v_transaction.currency || ' has been completed.' || CASE WHEN p_tx_hash IS NOT NULL THEN ' TX: ' || p_tx_hash ELSE '' END,
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
