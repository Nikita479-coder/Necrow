/*
  # Fix admin_process_withdrawal: Always Clear locked_balance

  1. Problem
    - When approving a withdrawal, the wallet update was guarded by
      `IF v_wallet.balance >= v_amount`
    - If the balance dropped below the withdrawal amount between submission
      and approval (due to concurrent operations), the entire wallet update
      was skipped silently
    - This left `locked_balance` permanently stuck at the withdrawal amount
    - New deposits would appear in `balance` but `main_available` would
      show 0 because `balance - locked_balance <= 0`

  2. Solution
    - Always clear `locked_balance` when approving a withdrawal
    - Use `GREATEST(0, ...)` to prevent negative values
    - Remove the balance guard that could skip the entire wallet update

  3. Security
    - No RLS changes
    - SECURITY DEFINER with explicit search_path (unchanged)
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
    UPDATE transactions
    SET 
      status = 'completed',
      tx_hash = COALESCE(p_tx_hash, tx_hash),
      address = COALESCE(p_wallet_address, address),
      network = COALESCE(p_network, network),
      admin_notes = p_admin_notes,
      details = NULL,
      confirmed_at = NOW(),
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
        balance = GREATEST(0, balance - v_amount),
        locked_balance = GREATEST(0, locked_balance - v_amount),
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
        'network', COALESCE(p_network, v_transaction.network),
        'wallet_address', COALESCE(p_wallet_address, v_transaction.address),
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
        locked_balance = GREATEST(0, locked_balance - v_amount),
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
