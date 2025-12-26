/*
  # Fix award_user_bonus Wallet Update

  ## Summary
  Updates the `award_user_bonus` function to properly update the wallet balance
  with the updated_at timestamp and ensure RLS doesn't block the operation.

  ## Changes
  - Explicitly sets updated_at when updating wallet balance
  - Uses RETURNING clause to verify the update succeeded
*/

-- Fix award_user_bonus to properly update wallet with timestamp
CREATE OR REPLACE FUNCTION award_user_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid,
  p_notes text DEFAULT NULL,
  p_expiry_days integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus_id uuid;
  v_wallet_id uuid;
  v_bonus_type_name text;
  v_expires_at timestamptz;
  v_new_balance numeric;
BEGIN
  -- Get bonus type name
  SELECT name INTO v_bonus_type_name FROM bonus_types WHERE id = p_bonus_type_id AND is_active = true;
  
  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;
  
  -- Calculate expiry
  IF p_expiry_days IS NOT NULL AND p_expiry_days > 0 THEN
    v_expires_at := now() + (p_expiry_days || ' days')::interval;
  END IF;

  -- Create bonus record with bonus_type_name
  INSERT INTO user_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    amount,
    status,
    awarded_by,
    awarded_at,
    expires_at,
    notes
  ) VALUES (
    p_user_id,
    p_bonus_type_id,
    v_bonus_type_name,
    p_amount,
    'active',
    p_awarded_by,
    now(),
    v_expires_at,
    p_notes
  ) RETURNING id INTO v_bonus_id;

  -- Get or create main wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'main', 0)
    ON CONFLICT (user_id, currency, wallet_type) 
    DO UPDATE SET balance = wallets.balance
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Credit the wallet with explicit updated_at
  UPDATE wallets
  SET 
    balance = balance + p_amount,
    updated_at = now()
  WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  -- Verify update succeeded
  IF v_new_balance IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Failed to update wallet balance'
    );
  END IF;

  -- Log transaction (use 'reward' type which is allowed)
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details
  ) VALUES (
    p_user_id,
    'reward',
    'USDT',
    p_amount,
    'completed',
    'Bonus: ' || v_bonus_type_name
  );

  -- Send notification (use 'account_update' type which is allowed)
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    read,
    data
  ) VALUES (
    p_user_id,
    'Bonus Awarded!',
    format('You have received a %s bonus of $%s USDT!', v_bonus_type_name, p_amount::text),
    'account_update',
    false,
    jsonb_build_object(
      'bonus_id', v_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name
    )
  );

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_awarded_by,
    'bonus_award',
    format('Awarded %s bonus of $%s to user', v_bonus_type_name, p_amount::text),
    p_user_id,
    jsonb_build_object(
      'bonus_type', v_bonus_type_name,
      'amount', p_amount,
      'bonus_id', v_bonus_id,
      'notes', COALESCE(p_notes, 'No notes'),
      'expiry_days', p_expiry_days,
      'new_balance', v_new_balance
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bonus awarded successfully',
    'bonus_id', v_bonus_id,
    'new_balance', v_new_balance
  );
END;
$$;
