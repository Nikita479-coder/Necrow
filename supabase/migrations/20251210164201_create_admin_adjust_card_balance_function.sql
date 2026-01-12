/*
  # Create Admin Adjust Card Balance Function

  1. New Functions
    - `admin_adjust_card_balance`: Allows admins to adjust shark card balances
      - Takes card_id and new_balance as parameters
      - Creates a transaction record for the adjustment
      - Returns success status with old and new balance

  2. Security
    - Only admins can execute this function
    - Validates card exists
    - Uses 'transfer' transaction type for admin adjustments
*/

CREATE OR REPLACE FUNCTION admin_adjust_card_balance(
  p_card_id uuid,
  p_new_balance numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card_record RECORD;
  v_old_balance numeric;
  v_adjustment numeric;
BEGIN
  -- Check if user is admin
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get card details
  SELECT * INTO v_card_record
  FROM shark_cards
  WHERE card_id = p_card_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Card not found'
    );
  END IF;

  -- Store old balance
  v_old_balance := v_card_record.balance_usdt;
  v_adjustment := p_new_balance - v_old_balance;

  -- Update card balance
  UPDATE shark_cards
  SET 
    balance_usdt = p_new_balance,
    updated_at = now()
  WHERE card_id = p_card_id;

  -- Create transaction record for audit trail
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    description
  ) VALUES (
    v_card_record.user_id,
    'transfer',
    abs(v_adjustment),
    'USDT',
    'completed',
    CASE 
      WHEN v_adjustment > 0 THEN 'Admin credit to Shark Card'
      WHEN v_adjustment < 0 THEN 'Admin debit from Shark Card'
      ELSE 'Admin card balance adjustment'
    END
  );

  -- Log the action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    auth.uid(),
    'adjust_card_balance',
    v_card_record.user_id,
    jsonb_build_object(
      'card_id', p_card_id,
      'old_balance', v_old_balance,
      'new_balance', p_new_balance,
      'adjustment', v_adjustment
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_old_balance,
    'new_balance', p_new_balance,
    'adjustment', v_adjustment
  );
END;
$$;