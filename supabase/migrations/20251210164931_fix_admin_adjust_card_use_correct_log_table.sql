/*
  # Fix Admin Adjust Card Balance - Use Correct Log Table

  1. Changes
    - Use admin_activity_logs instead of admin_action_logs
    - Adjust column names to match admin_activity_logs schema

  2. Security
    - Only admins can execute
    - Logs all actions
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
  v_description text;
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

  -- Store old balance (available_credit)
  v_old_balance := v_card_record.available_credit;
  v_adjustment := p_new_balance - v_old_balance;

  -- Build description based on adjustment
  IF v_adjustment > 0 THEN
    v_description := 'Admin credited ' || v_adjustment::text || ' USDT to Shark Card';
  ELSIF v_adjustment < 0 THEN
    v_description := 'Admin debited ' || abs(v_adjustment)::text || ' USDT from Shark Card';
  ELSE
    v_description := 'Admin adjusted Shark Card balance (no change)';
  END IF;

  -- Update card available credit
  UPDATE shark_cards
  SET 
    available_credit = p_new_balance,
    updated_at = now()
  WHERE card_id = p_card_id;

  -- Create transaction record for audit trail
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status
  ) VALUES (
    v_card_record.user_id,
    'transfer',
    abs(v_adjustment),
    'USDT',
    'completed'
  );

  -- Log the action using admin_activity_logs
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    target_user_id,
    metadata
  ) VALUES (
    auth.uid(),
    'adjust_card_balance',
    v_description,
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