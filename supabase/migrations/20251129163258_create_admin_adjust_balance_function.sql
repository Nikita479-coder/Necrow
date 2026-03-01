/*
  # Create Admin Balance Adjustment Function

  ## Summary
  Creates a secure function for admins to adjust user wallet balances.
  This function bypasses RLS restrictions using SECURITY DEFINER and checks
  that the calling user is an admin before allowing balance adjustments.

  ## Changes
  1. Create admin_adjust_user_balance function
     - Checks if caller is admin (via JWT metadata)
     - Creates wallet if it doesn't exist
     - Updates balance if wallet exists
     - Records transaction for audit trail
     - Returns success/error response

  ## Security
  - Function uses SECURITY DEFINER to bypass RLS
  - Validates admin role from JWT metadata
  - Only allows admins to adjust balances
  - Prevents negative balances
*/

CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_amount numeric,
  p_currency text DEFAULT 'USDT'
)
RETURNS jsonb AS $$
DECLARE
  v_wallet_record record;
  v_new_balance numeric;
  v_is_admin boolean;
BEGIN
  -- Check if caller is admin
  v_is_admin := COALESCE(
    (auth.jwt()->>'is_admin')::boolean,
    false
  );

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Validate amount
  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Amount cannot be zero or null'
    );
  END IF;

  -- Check if wallet exists
  SELECT * INTO v_wallet_record
  FROM wallets
  WHERE user_id = p_user_id 
    AND currency = p_currency
    AND wallet_type = 'main';

  IF NOT FOUND THEN
    -- Create new wallet if it doesn't exist
    IF p_amount < 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Cannot create wallet with negative balance'
      );
    END IF;

    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, p_currency, 'main', p_amount)
    RETURNING * INTO v_wallet_record;

    -- Record transaction
    INSERT INTO transactions (
      user_id, type, amount, currency, status, description
    )
    VALUES (
      p_user_id,
      'deposit',
      p_amount,
      p_currency,
      'completed',
      'Admin adjustment - wallet created'
    );

    RETURN jsonb_build_object(
      'success', true,
      'message', format('Wallet created with balance: %s %s', p_amount, p_currency),
      'new_balance', p_amount,
      'wallet_created', true
    );
  END IF;

  -- Calculate new balance
  v_new_balance := v_wallet_record.balance + p_amount;

  -- Prevent negative balance
  IF v_new_balance < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Insufficient balance. Current: %s, Adjustment: %s', v_wallet_record.balance, p_amount)
    );
  END IF;

  -- Update wallet balance
  UPDATE wallets
  SET balance = v_new_balance,
      updated_at = now()
  WHERE id = v_wallet_record.id;

  -- Record transaction
  INSERT INTO transactions (
    user_id, type, amount, currency, status, description
  )
  VALUES (
    p_user_id,
    CASE WHEN p_amount > 0 THEN 'deposit' ELSE 'withdraw' END,
    abs(p_amount),
    p_currency,
    'completed',
    'Admin adjustment by system'
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Balance adjusted successfully: %s %s', p_amount, p_currency),
    'old_balance', v_wallet_record.balance,
    'new_balance', v_new_balance,
    'adjustment', p_amount
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Error adjusting balance: %s', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;