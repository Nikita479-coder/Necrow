/*
  # Fix admin_issue_shark_card notification column

  1. Changes
    - Update notifications table constraint to include all notification types (existing + new)
    - Fix admin_issue_shark_card function to use 'read' column instead of 'is_read'
*/

-- Update the constraint to include all existing notification types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN (
    'referral_payout', 'trade_executed', 'kyc_update', 'account_update', 'system', 
    'shark_card_issued', 'tpsl_triggered', 'tpsl_cancelled', 
    'withdrawal_blocked', 'withdrawal_unblocked', 'vip_level_upgraded',
    'position_closed', 'vip_downgrade', 'shark_card_application', 
    'position_tp_hit', 'vip_upgrade', 'shark_card_approved', 'shark_card_declined'
  ));

-- Fix the admin_issue_shark_card function to use 'read' instead of 'is_read'
CREATE OR REPLACE FUNCTION admin_issue_shark_card(
  p_application_id uuid,
  p_card_number text,
  p_cardholder_name text,
  p_expiry_month text,
  p_expiry_year text,
  p_cvv text,
  p_card_type text DEFAULT 'gold',
  p_admin_id uuid DEFAULT auth.uid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_card_id uuid;
  v_last_4 text;
  v_expiry_date timestamptz;
BEGIN
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
  END IF;

  SELECT user_id INTO v_user_id FROM shark_card_applications WHERE application_id = p_application_id AND status = 'approved';

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or not approved');
  END IF;

  v_last_4 := RIGHT(p_card_number, 4);
  v_expiry_date := (('20' || p_expiry_year || '-' || p_expiry_month || '-01')::date + INTERVAL '1 month' - INTERVAL '1 day')::timestamptz;

  INSERT INTO shark_cards (
    application_id, user_id, card_number, full_card_number, card_holder_name, credit_limit, available_credit, used_credit, cashback_rate,
    expiry_date, expiry_month, expiry_year, cvv, card_type, status, card_issued
  ) VALUES (
    p_application_id, v_user_id, v_last_4, p_card_number, p_cardholder_name, 5000, 5000, 0,
    CASE WHEN p_card_type = 'platinum' THEN 3.0 WHEN p_card_type = 'gold' THEN 2.0 ELSE 1.0 END,
    v_expiry_date, p_expiry_month, p_expiry_year, p_cvv, p_card_type, 'active', true
  ) RETURNING card_id INTO v_card_id;

  INSERT INTO wallets (user_id, currency, balance, wallet_type, total_deposited)
  VALUES (v_user_id, 'USDT', 5000, 'card', 5000)
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET balance = wallets.balance + 5000, total_deposited = wallets.total_deposited + 5000;

  UPDATE shark_card_applications SET status = 'issued', reviewed_at = now(), reviewed_by = p_admin_id, updated_at = now()
  WHERE application_id = p_application_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (v_user_id, 'shark_card_issued', 'Shark Card Issued!', 
    'Congratulations! Your Shark Card has been issued with 5000 USDT balance. You can now view your card details.', false);

  INSERT INTO admin_action_logs (admin_id, action_type, target_user_id, details, ip_address)
  VALUES (p_admin_id, 'shark_card_issued', v_user_id,
    jsonb_build_object('card_id', v_card_id, 'application_id', p_application_id, 'card_type', p_card_type, 'last_4', v_last_4), NULL);

  RETURN jsonb_build_object('success', true, 'card_id', v_card_id, 'message', 'Card issued successfully');
END;
$$;