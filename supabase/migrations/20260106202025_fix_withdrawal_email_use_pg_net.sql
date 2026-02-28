/*
  # Fix Withdrawal Email Function - Use pg_net for Async HTTP

  1. Changes
    - Use pg_net.http_post for async HTTP calls (better for non-blocking)
    - Fix column name from destination_address to address
    - Use existing network column from transaction
*/

DROP FUNCTION IF EXISTS admin_process_withdrawal(uuid, text, text, text, text, text);

CREATE OR REPLACE FUNCTION admin_process_withdrawal(
  p_transaction_id uuid,
  p_action text,
  p_tx_hash text DEFAULT NULL,
  p_admin_notes text DEFAULT NULL,
  p_network text DEFAULT NULL,
  p_wallet_address text DEFAULT NULL
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
  v_net_amount numeric;
  v_supabase_url text;
  v_service_key text;
  v_request_id bigint;
BEGIN
  IF NOT is_user_admin(v_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  IF p_action NOT IN ('approve', 'reject', 'complete') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid action. Must be approve, reject, or complete'
    );
  END IF;

  SELECT * INTO v_transaction
  FROM transactions
  WHERE id = p_transaction_id AND transaction_type = 'withdrawal';

  IF v_transaction IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Withdrawal not found'
    );
  END IF;

  CASE p_action
    WHEN 'approve' THEN v_new_status := 'processing';
    WHEN 'complete' THEN v_new_status := 'completed';
    WHEN 'reject' THEN v_new_status := 'failed';
  END CASE;

  UPDATE transactions
  SET status = v_new_status,
      tx_hash = COALESCE(p_tx_hash, tx_hash),
      confirmed_at = CASE WHEN p_action = 'complete' THEN now() ELSE confirmed_at END,
      updated_at = now()
  WHERE id = p_transaction_id;

  IF p_action = 'reject' THEN
    UPDATE wallets
    SET balance = balance + v_transaction.amount,
        updated_at = now()
    WHERE user_id = v_transaction.user_id 
      AND currency = v_transaction.currency 
      AND wallet_type = 'main';

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_rejected',
      'Withdrawal Rejected',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been rejected. ' || COALESCE('Reason: ' || p_admin_notes, 'Please contact support for more information.') || ' The funds have been returned to your wallet.',
      false
    );
  ELSIF p_action = 'approve' THEN
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_approved',
      'Withdrawal Approved',
      'Your withdrawal request for ' || v_transaction.amount || ' ' || v_transaction.currency || ' has been approved and is being processed.',
      false
    );
  ELSIF p_action = 'complete' THEN
    v_net_amount := v_transaction.amount - COALESCE(v_transaction.fee, 0);
    
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_transaction.user_id,
      'withdrawal_completed',
      'Withdrawal Completed',
      'Your withdrawal of ' || v_net_amount || ' ' || v_transaction.currency || ' has been completed.' || CASE WHEN p_tx_hash IS NOT NULL THEN ' TX: ' || p_tx_hash ELSE '' END,
      false
    );
    
    -- Trigger withdrawal email via edge function using pg_net
    BEGIN
      SELECT extensions.http_post(
        url := 'https://lhovlggjjpimxqkdeqhc.supabase.co/functions/v1/send-withdrawal-email',
        body := jsonb_build_object(
          'user_id', v_transaction.user_id,
          'amount', v_transaction.amount::text,
          'fee', COALESCE(v_transaction.fee, 0)::text,
          'net_amount', v_net_amount::text,
          'currency', v_transaction.currency,
          'network', COALESCE(p_network, v_transaction.network, 'TRC20'),
          'wallet_address', COALESCE(p_wallet_address, v_transaction.address, 'N/A'),
          'tx_hash', COALESCE(p_tx_hash, 'N/A')
        )::text,
        headers := '{"Content-Type": "application/json"}'::jsonb
      ) INTO v_request_id;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the withdrawal
      RAISE NOTICE 'Failed to send withdrawal email: %', SQLERRM;
    END;
  END IF;

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
      'network', COALESCE(p_network, v_transaction.network),
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
