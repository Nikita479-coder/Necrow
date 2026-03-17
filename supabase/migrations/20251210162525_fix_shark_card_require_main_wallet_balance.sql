/*
  # Fix Shark Card issuance to require main wallet balance

  1. Changes
    - Check if user has 5000 USDT in main wallet before issuing card
    - Transfer funds from main wallet to card wallet instead of creating money
    - Add proper transaction records for the transfer
*/

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
  v_main_wallet_balance numeric;
  v_credit_limit numeric := 5000;
BEGIN
  -- Check admin permissions
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
  END IF;

  -- Get user_id from approved application
  SELECT user_id INTO v_user_id 
  FROM shark_card_applications 
  WHERE application_id = p_application_id AND status = 'approved';

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or not approved');
  END IF;

  -- Check if user has 5000 USDT in main wallet
  SELECT COALESCE(balance, 0) INTO v_main_wallet_balance
  FROM wallets
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  IF v_main_wallet_balance < v_credit_limit THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Insufficient balance in main wallet. User needs 5000 USDT to issue a Shark Card.',
      'current_balance', v_main_wallet_balance,
      'required_balance', v_credit_limit
    );
  END IF;

  -- Deduct from main wallet
  UPDATE wallets
  SET balance = balance - v_credit_limit,
      updated_at = now()
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';

  -- Create card
  v_last_4 := RIGHT(p_card_number, 4);
  v_expiry_date := (('20' || p_expiry_year || '-' || p_expiry_month || '-01')::date + INTERVAL '1 month' - INTERVAL '1 day')::timestamptz;

  INSERT INTO shark_cards (
    application_id, 
    user_id, 
    card_number, 
    full_card_number, 
    card_holder_name, 
    credit_limit, 
    available_credit, 
    used_credit, 
    cashback_rate,
    expiry_date, 
    expiry_month, 
    expiry_year, 
    cvv, 
    card_type, 
    status, 
    card_issued
  ) VALUES (
    p_application_id, 
    v_user_id, 
    v_last_4, 
    p_card_number, 
    p_cardholder_name, 
    v_credit_limit, 
    v_credit_limit, 
    0,
    CASE 
      WHEN p_card_type = 'platinum' THEN 3.0 
      WHEN p_card_type = 'gold' THEN 2.0 
      ELSE 1.0 
    END,
    v_expiry_date, 
    p_expiry_month, 
    p_expiry_year, 
    p_cvv, 
    p_card_type, 
    'active', 
    true
  ) RETURNING card_id INTO v_card_id;

  -- Create or update card wallet
  INSERT INTO wallets (user_id, currency, balance, wallet_type, total_deposited)
  VALUES (v_user_id, 'USDT', v_credit_limit, 'card', v_credit_limit)
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET 
    balance = wallets.balance + v_credit_limit, 
    total_deposited = wallets.total_deposited + v_credit_limit,
    updated_at = now();

  -- Create transaction record for the transfer
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    confirmed_at
  ) VALUES (
    v_user_id,
    'transfer',
    'USDT',
    v_credit_limit,
    'completed',
    now()
  );

  -- Update application status
  UPDATE shark_card_applications 
  SET status = 'issued', 
      reviewed_at = now(), 
      reviewed_by = p_admin_id, 
      updated_at = now()
  WHERE application_id = p_application_id;

  -- Send notification to user
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id, 
    'shark_card_issued', 
    'Shark Card Issued!', 
    'Congratulations! Your Shark Card has been issued with ' || v_credit_limit || ' USDT balance transferred from your main wallet. You can now view your card details.', 
    false
  );

  -- Log admin action
  INSERT INTO admin_activity_logs (
    admin_id, 
    action_type, 
    action_description, 
    target_user_id, 
    metadata
  ) VALUES (
    p_admin_id, 
    'shark_card_issued', 
    'Issued Shark Card with ' || v_credit_limit || ' USDT transferred from main wallet', 
    v_user_id,
    jsonb_build_object(
      'card_id', v_card_id, 
      'application_id', p_application_id, 
      'card_type', p_card_type, 
      'last_4', v_last_4,
      'amount_transferred', v_credit_limit
    )
  );

  RETURN jsonb_build_object(
    'success', true, 
    'card_id', v_card_id, 
    'message', 'Card issued successfully. ' || v_credit_limit || ' USDT transferred from main wallet to card wallet.'
  );
END;
$$;