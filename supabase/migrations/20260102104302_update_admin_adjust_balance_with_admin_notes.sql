/*
  # Update Admin Balance Adjustment Function with Admin Notes

  1. Changes
    - Update function to accept separate user-facing and admin-only messages
    - Store generic message in `details` (visible to users)
    - Store sensitive information in `admin_notes` (admin-only)
  
  2. Security
    - Users see generic messages like "Balance adjustment by admin"
    - Admins see full context in admin_notes
*/

CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'Balance adjustment by admin',
  p_currency text DEFAULT 'USDT',
  p_admin_notes text DEFAULT NULL
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
  v_user_facing_message text;
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

  -- Create generic user-facing message if not provided
  IF p_description IS NULL OR p_description = '' THEN
    v_user_facing_message := CASE 
      WHEN p_amount > 0 THEN 'Balance credit by admin'
      ELSE 'Balance adjustment by admin'
    END;
  ELSE
    -- Sanitize the description to remove sensitive keywords
    v_user_facing_message := p_description;
    IF v_user_facing_message ~* '(bug|exploit|issue|error|problem|avoided|liquidation|reset)' THEN
      v_user_facing_message := 'Balance adjustment by admin';
    END IF;
  END IF;

  -- Log transaction with generic user-facing message and detailed admin notes
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    admin_notes,
    confirmed_at
  ) VALUES (
    p_user_id,
    CASE WHEN p_amount > 0 THEN 'admin_credit' ELSE 'admin_debit' END,
    p_currency,
    abs(p_amount),
    'completed',
    v_user_facing_message,  -- Generic message visible to user
    COALESCE(p_admin_notes, p_description),  -- Detailed notes for admin only
    now()
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
    COALESCE(p_admin_notes, p_description),
    jsonb_build_object(
      'adjustment_type', CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance,
      'user_facing_message', v_user_facing_message,
      'admin_notes', COALESCE(p_admin_notes, p_description)
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
      COALESCE(p_admin_notes, p_description)
    ),
    p_user_id,
    jsonb_build_object(
      'currency', p_currency,
      'amount', p_amount,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance,
      'user_facing_message', v_user_facing_message,
      'admin_notes', COALESCE(p_admin_notes, p_description)
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Balance adjusted successfully. New balance: %s %s', v_new_balance::text, p_currency),
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'user_facing_message', v_user_facing_message,
    'admin_notes', COALESCE(p_admin_notes, p_description)
  );
END;
$$;
