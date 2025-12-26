/*
  # Add Custom Description to Admin Balance Adjustment

  1. Changes
    - Add p_description parameter to admin_adjust_user_balance function
    - Store custom description in transaction details
    - Always adds to main wallet USDT by default
    
  2. Features
    - Admin can specify custom description like "Crypto Deposit Refund", "Bonus Award", etc.
    - Description shows up in user's transaction history
    - Maintains all existing logging functionality
*/

CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'Admin Balance Adjustment',
  p_currency text DEFAULT 'USDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_admin_id uuid;
BEGIN
  -- Get admin ID from session
  v_admin_id := auth.uid();

  -- Get or create main wallet
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_currency AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
    VALUES (p_user_id, p_currency, 'main', 0, 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
    
    SELECT id, balance INTO v_wallet_id, v_old_balance
    FROM wallets
    WHERE user_id = p_user_id AND currency = p_currency AND wallet_type = 'main';
  END IF;

  -- Calculate new balance
  v_new_balance := v_old_balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Current: %s, Adjustment: %s', v_old_balance, p_amount)
    );
  END IF;

  -- Update balance
  UPDATE wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  -- Log transaction with custom description
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    wallet_id,
    details
  ) VALUES (
    p_user_id,
    CASE WHEN p_amount > 0 THEN 'admin_credit' ELSE 'admin_debit' END,
    p_currency,
    abs(p_amount),
    'completed',
    v_wallet_id,
    p_description
  );

  -- LOG FINANCIAL TRANSACTION
  INSERT INTO financial_transaction_logs (
    user_id,
    transaction_type,
    currency,
    amount,
    before_balance,
    after_balance,
    executed_by_admin_id,
    reason,
    metadata
  ) VALUES (
    p_user_id,
    'admin_balance_adjustment',
    p_currency,
    p_amount,
    v_old_balance,
    v_new_balance,
    v_admin_id,
    p_description,
    jsonb_build_object(
      'adjustment_type', CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance,
      'description', p_description
    )
  );

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    v_admin_id,
    'balance_adjustment',
    format('Adjusted balance by %s%s %s: %s', 
      CASE WHEN p_amount > 0 THEN '+' ELSE '' END,
      p_amount::text,
      p_currency,
      p_description
    ),
    p_user_id,
    jsonb_build_object(
      'currency', p_currency,
      'amount', p_amount,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance,
      'description', p_description
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Balance adjusted successfully. New balance: %s %s', v_new_balance::text, p_currency),
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'description', p_description
  );
END;
$$;
