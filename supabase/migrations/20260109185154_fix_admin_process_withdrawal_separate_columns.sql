/*
  # Fix Admin Process Withdrawal to Use Separate Columns

  1. Problem
    - Function stores all admin data (admin_notes, tx_hash, network, wallet_address) in details JSON
    - This exposes admin_notes to users when they query transactions
    
  2. Solution
    - Store admin_notes in admin_notes column
    - Store tx_hash in tx_hash column
    - Store wallet_address in address column
    - Store network in network column
    - Keep details simple or null
    
  3. Security
    - Admin notes are now properly hidden from users
    - Users only see their withdrawal address in the description
*/

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
  v_transaction RECORD;
  v_user_id uuid;
  v_amount numeric;
  v_currency text;
  v_wallet RECORD;
  v_admin_id uuid;
BEGIN
  v_admin_id := auth.uid();
  
  IF NOT is_user_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  SELECT * INTO v_transaction
  FROM transactions
  WHERE id = p_transaction_id
    AND transaction_type = 'withdrawal'
    AND status = 'pending';

  IF v_transaction IS NULL THEN
    RAISE EXCEPTION 'Withdrawal transaction not found or not pending';
  END IF;

  v_user_id := v_transaction.user_id;
  v_amount := ABS(v_transaction.amount);
  v_currency := v_transaction.currency;

  IF p_action = 'approve' THEN
    -- Store data in proper columns, not in details JSON
    UPDATE transactions
    SET 
      status = 'completed',
      tx_hash = p_tx_hash,
      address = p_wallet_address,
      network = p_network,
      admin_notes = p_admin_notes,
      details = NULL,  -- Keep details simple
      confirmed_at = NOW(),
      updated_at = NOW()
    WHERE id = p_transaction_id;

    SELECT * INTO v_wallet
    FROM wallets
    WHERE user_id = v_user_id
      AND currency = v_currency
      AND wallet_type = 'main';

    IF v_wallet IS NOT NULL AND v_wallet.balance >= v_amount THEN
      UPDATE wallets
      SET 
        balance = balance - v_amount,
        updated_at = NOW()
      WHERE id = v_wallet.id;
    END IF;

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_user_id,
      'withdrawal_approved',
      'Withdrawal Approved',
      format('Your withdrawal of %s %s has been approved and processed.', v_amount, v_currency),
      false
    );

    INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
    VALUES (
      v_admin_id,
      'withdrawal_approved',
      format('Approved withdrawal of %s %s', v_amount, v_currency),
      v_user_id,
      jsonb_build_object(
        'transaction_id', p_transaction_id,
        'amount', v_amount,
        'currency', v_currency,
        'tx_hash', p_tx_hash,
        'network', p_network,
        'wallet_address', p_wallet_address,
        'admin_notes', p_admin_notes
      )
    );

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Withdrawal approved successfully'
    );

  ELSIF p_action = 'reject' THEN
    UPDATE transactions
    SET 
      status = 'failed',
      admin_notes = COALESCE(p_admin_notes, 'Withdrawal rejected by admin'),
      details = 'Withdrawal rejected',
      updated_at = NOW()
    WHERE id = p_transaction_id;

    SELECT * INTO v_wallet
    FROM wallets
    WHERE user_id = v_user_id
      AND currency = v_currency
      AND wallet_type = 'main';

    IF v_wallet IS NOT NULL THEN
      UPDATE wallets
      SET 
        balance = balance + v_amount,
        updated_at = NOW()
      WHERE id = v_wallet.id;
    END IF;

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_user_id,
      'withdrawal_rejected',
      'Withdrawal Rejected',
      format('Your withdrawal of %s %s has been rejected. Reason: %s', 
        v_amount, v_currency, COALESCE(p_admin_notes, 'Contact support for details')),
      false
    );

    INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
    VALUES (
      v_admin_id,
      'withdrawal_rejected',
      format('Rejected withdrawal of %s %s', v_amount, v_currency),
      v_user_id,
      jsonb_build_object(
        'transaction_id', p_transaction_id,
        'amount', v_amount,
        'currency', v_currency,
        'reason', p_admin_notes
      )
    );

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Withdrawal rejected and funds returned to user'
    );

  ELSE
    RAISE EXCEPTION 'Invalid action. Use approve or reject';
  END IF;
END;
$$;
