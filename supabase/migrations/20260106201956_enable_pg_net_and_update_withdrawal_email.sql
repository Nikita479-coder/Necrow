/*
  # Enable pg_net and Update Withdrawal Processing to Send Email
  
  1. Changes
    - Enable pg_net extension for async HTTP calls
    - Update admin_process_withdrawal function to trigger withdrawal email on completion
  
  2. Email Details
    - Automatically sends withdrawal confirmation email when admin marks withdrawal as complete
    - Includes all transaction details: amount, fee, network, wallet address, tx hash
*/

-- Enable pg_net extension for async HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Drop existing function to recreate with email trigger
DROP FUNCTION IF EXISTS admin_process_withdrawal(uuid, text, text, text);
DROP FUNCTION IF EXISTS admin_process_withdrawal(uuid, text, text, text, text, text);

CREATE OR REPLACE FUNCTION admin_process_withdrawal(
  p_transaction_id uuid,
  p_action text,
  p_tx_hash text DEFAULT NULL,
  p_admin_notes text DEFAULT NULL,
  p_network text DEFAULT 'TRC20',
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
    
    -- Trigger withdrawal email via edge function
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    v_service_key := current_setting('app.settings.service_role_key', true);
    
    IF v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL THEN
      PERFORM extensions.http_post(
        url := v_supabase_url || '/functions/v1/send-withdrawal-email',
        body := jsonb_build_object(
          'user_id', v_transaction.user_id,
          'amount', v_transaction.amount::text,
          'fee', COALESCE(v_transaction.fee, 0)::text,
          'net_amount', v_net_amount::text,
          'currency', v_transaction.currency,
          'network', COALESCE(p_network, 'TRC20'),
          'wallet_address', COALESCE(p_wallet_address, v_transaction.destination_address, 'N/A'),
          'tx_hash', COALESCE(p_tx_hash, 'N/A')
        )::text,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_key
        )::text
      );
    END IF;
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
      'network', p_network,
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
