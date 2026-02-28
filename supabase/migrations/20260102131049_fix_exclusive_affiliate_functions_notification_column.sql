/*
  # Fix Exclusive Affiliate Functions - Notification Column Name

  ## Summary
  Fixes the `admin_enroll_exclusive_affiliate` function to use the correct column name
  `read` instead of `is_read` for the notifications table.

  ## Changes
  1. Recreates `admin_enroll_exclusive_affiliate` with correct column name
  2. Recreates `admin_remove_exclusive_affiliate` for completeness
  3. Adds `admin_process_exclusive_withdrawal` function for withdrawal management
*/

-- Fix the enroll function with correct notification column
CREATE OR REPLACE FUNCTION admin_enroll_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1}'::jsonb,
  p_fee_rates jsonb DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_user_email;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
  
  INSERT INTO exclusive_affiliates (
    user_id,
    enrolled_by,
    deposit_commission_rates,
    fee_share_rates,
    is_active
  ) VALUES (
    v_user_id,
    p_admin_id,
    p_deposit_rates,
    p_fee_rates,
    true
  )
  ON CONFLICT (user_id) DO UPDATE SET
    deposit_commission_rates = EXCLUDED.deposit_commission_rates,
    fee_share_rates = EXCLUDED.fee_share_rates,
    is_active = true,
    updated_at = now();
  
  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;
  
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id,
    'system',
    'VIP Affiliate Program Activated',
    'Congratulations! You have been enrolled in the exclusive VIP Affiliate Program. You now earn deposit commissions (5-1%) and trading fee revenue share (50-10%) from your 5-level network.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', p_user_email,
    'deposit_rates', p_deposit_rates,
    'fee_rates', p_fee_rates
  );
END;
$$;

-- Fix the remove function
CREATE OR REPLACE FUNCTION admin_remove_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_user_email;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
  
  UPDATE exclusive_affiliates
  SET is_active = false, updated_at = now()
  WHERE user_id = v_user_id;
  
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id,
    'system',
    'Affiliate Program Status Changed',
    'Your exclusive affiliate program status has been updated. Please contact support if you have any questions.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'message', 'User removed from exclusive affiliate program'
  );
END;
$$;

-- Create withdrawal processing function
CREATE OR REPLACE FUNCTION admin_process_exclusive_withdrawal(
  p_admin_id uuid,
  p_withdrawal_id uuid,
  p_action text,
  p_rejection_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_withdrawal record;
  v_new_status text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT * INTO v_withdrawal
  FROM exclusive_affiliate_withdrawals
  WHERE id = p_withdrawal_id AND status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Withdrawal not found or already processed');
  END IF;
  
  IF p_action = 'approve' THEN
    v_new_status := 'completed';
    
    UPDATE exclusive_affiliate_balances
    SET pending_balance = pending_balance - v_withdrawal.amount,
        total_withdrawn = total_withdrawn + v_withdrawal.amount,
        updated_at = now()
    WHERE user_id = v_withdrawal.user_id;
    
    INSERT INTO notifications (user_id, type, title, message, read, data)
    VALUES (
      v_withdrawal.user_id,
      'withdrawal_approved',
      'Affiliate Withdrawal Approved',
      format('Your withdrawal of $%s %s has been approved and sent to your wallet.', 
        v_withdrawal.amount, v_withdrawal.currency),
      false,
      jsonb_build_object('amount', v_withdrawal.amount, 'currency', v_withdrawal.currency)
    );
    
  ELSIF p_action = 'reject' THEN
    v_new_status := 'rejected';
    
    UPDATE exclusive_affiliate_balances
    SET available_balance = available_balance + v_withdrawal.amount,
        pending_balance = pending_balance - v_withdrawal.amount,
        updated_at = now()
    WHERE user_id = v_withdrawal.user_id;
    
    INSERT INTO notifications (user_id, type, title, message, read, data)
    VALUES (
      v_withdrawal.user_id,
      'withdrawal_rejected',
      'Affiliate Withdrawal Rejected',
      format('Your withdrawal of $%s %s has been rejected. Reason: %s. The funds have been returned to your available balance.', 
        v_withdrawal.amount, v_withdrawal.currency, COALESCE(p_rejection_reason, 'Not specified')),
      false,
      jsonb_build_object('amount', v_withdrawal.amount, 'currency', v_withdrawal.currency, 'reason', p_rejection_reason)
    );
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Invalid action. Use approve or reject');
  END IF;
  
  UPDATE exclusive_affiliate_withdrawals
  SET status = v_new_status,
      processed_by = p_admin_id,
      processed_at = now(),
      rejection_reason = CASE WHEN p_action = 'reject' THEN p_rejection_reason ELSE NULL END
  WHERE id = p_withdrawal_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', p_withdrawal_id,
    'new_status', v_new_status,
    'user_id', v_withdrawal.user_id,
    'amount', v_withdrawal.amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_enroll_exclusive_affiliate TO authenticated;
GRANT EXECUTE ON FUNCTION admin_remove_exclusive_affiliate TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_exclusive_withdrawal TO authenticated;
