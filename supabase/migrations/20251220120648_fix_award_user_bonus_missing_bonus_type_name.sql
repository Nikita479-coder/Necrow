/*
  # Fix award_user_bonus Function - Missing bonus_type_name Column

  ## Summary
  Fixes the `award_user_bonus` function to include the required `bonus_type_name` 
  column in the INSERT statement for the `user_bonuses` table.

  ## Issue
  The function retrieves `v_bonus_type_name` but doesn't include it in the INSERT,
  causing a NOT NULL constraint violation.

  ## Changes
  - Adds `bonus_type_name` column to the INSERT statement
  - Ensures the bonus name is properly stored for display in admin panels
*/

-- Fix award_user_bonus to include bonus_type_name
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

  -- Credit the wallet
  UPDATE wallets
  SET balance = balance + p_amount
  WHERE id = v_wallet_id;

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    wallet_id
  ) VALUES (
    p_user_id,
    'bonus',
    'USDT',
    p_amount,
    'completed',
    v_wallet_id
  );

  -- Send notification
  INSERT INTO notifications (
    user_id,
    title,
    message,
    category,
    status
  ) VALUES (
    p_user_id,
    'Bonus Awarded!',
    format('You have received a %s bonus of $%s USDT!', v_bonus_type_name, p_amount::text),
    'bonus',
    'unread'
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
      'expiry_days', p_expiry_days
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bonus awarded successfully',
    'bonus_id', v_bonus_id
  );
END;
$$;
