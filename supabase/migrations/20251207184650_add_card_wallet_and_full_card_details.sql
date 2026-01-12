/*
  # Add Card Wallet Type and Full Shark Card Details
  
  1. Wallet Changes
    - Add 'card' to wallet_type constraint
    - Allow card wallet for Shark Card balance
  
  2. Shark Cards Table Updates
    - Add cvv field
    - Add expiry_month and expiry_year fields
    - Update card_number to store full 16-digit number
    - Add card_issued flag
  
  3. Functions
    - `admin_issue_shark_card` - Issues a physical card with details and allocates 5000 USDT to card wallet
    - `get_user_shark_card` - Retrieves user's active shark card with details
*/

-- Update wallet_type constraint to include 'card'
DO $$
BEGIN
  ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_wallet_type_check;
  ALTER TABLE wallets ADD CONSTRAINT wallets_wallet_type_check 
    CHECK (wallet_type IN ('main', 'assets', 'copy', 'futures', 'card'));
END $$;

-- Add new fields to shark_cards table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_cards' AND column_name = 'cvv'
  ) THEN
    ALTER TABLE shark_cards ADD COLUMN cvv text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_cards' AND column_name = 'expiry_month'
  ) THEN
    ALTER TABLE shark_cards ADD COLUMN expiry_month text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_cards' AND column_name = 'expiry_year'
  ) THEN
    ALTER TABLE shark_cards ADD COLUMN expiry_year text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_cards' AND column_name = 'card_issued'
  ) THEN
    ALTER TABLE shark_cards ADD COLUMN card_issued boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_cards' AND column_name = 'full_card_number'
  ) THEN
    ALTER TABLE shark_cards ADD COLUMN full_card_number text;
  END IF;
END $$;

-- Function to issue a Shark Card with full details
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
  -- Check if caller is admin
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get user_id from application
  SELECT user_id INTO v_user_id
  FROM shark_card_applications
  WHERE application_id = p_application_id
  AND status = 'approved';

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Application not found or not approved'
    );
  END IF;

  -- Extract last 4 digits for display
  v_last_4 := RIGHT(p_card_number, 4);

  -- Calculate expiry date (last day of the month)
  v_expiry_date := (
    ('20' || p_expiry_year || '-' || p_expiry_month || '-01')::date + 
    INTERVAL '1 month' - INTERVAL '1 day'
  )::timestamptz;

  -- Create the shark card
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
    5000,
    5000,
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

  -- Create or update card wallet with 5000 USDT
  INSERT INTO wallets (user_id, currency, balance, wallet_type, total_deposited)
  VALUES (v_user_id, 'USDT', 5000, 'card', 5000)
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET 
    balance = wallets.balance + 5000,
    total_deposited = wallets.total_deposited + 5000;

  -- Update application status to issued
  UPDATE shark_card_applications
  SET 
    status = 'issued',
    reviewed_at = now(),
    reviewed_by = p_admin_id,
    updated_at = now()
  WHERE application_id = p_application_id;

  -- Create notification for user
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    v_user_id,
    'shark_card_issued',
    'Shark Card Issued!',
    'Congratulations! Your Shark Card has been issued with 5000 USDT balance. You can now view your card details.',
    false
  );

  -- Log the action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    p_admin_id,
    'shark_card_issued',
    v_user_id,
    jsonb_build_object(
      'card_id', v_card_id,
      'application_id', p_application_id,
      'card_type', p_card_type,
      'last_4', v_last_4
    ),
    NULL
  );

  RETURN jsonb_build_object(
    'success', true,
    'card_id', v_card_id,
    'message', 'Card issued successfully'
  );
END;
$$;

-- Function to get user's Shark Card details
CREATE OR REPLACE FUNCTION get_user_shark_card(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card record;
  v_wallet_balance numeric;
BEGIN
  -- Check if caller is the user or admin
  IF p_user_id != auth.uid() AND NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized'
    );
  END IF;

  -- Get the active card
  SELECT * INTO v_card
  FROM shark_cards
  WHERE user_id = p_user_id
  AND status = 'active'
  AND card_issued = true
  ORDER BY issue_date DESC
  LIMIT 1;

  IF v_card IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'has_card', false
    );
  END IF;

  -- Get card wallet balance
  SELECT COALESCE(balance, 0) INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_user_id
  AND currency = 'USDT'
  AND wallet_type = 'card';

  RETURN jsonb_build_object(
    'success', true,
    'has_card', true,
    'card', jsonb_build_object(
      'card_id', v_card.card_id,
      'card_number', v_card.full_card_number,
      'last_4', v_card.card_number,
      'cardholder_name', v_card.card_holder_name,
      'expiry_month', v_card.expiry_month,
      'expiry_year', v_card.expiry_year,
      'cvv', v_card.cvv,
      'card_type', v_card.card_type,
      'credit_limit', v_card.credit_limit,
      'available_credit', v_card.available_credit,
      'used_credit', v_card.used_credit,
      'cashback_rate', v_card.cashback_rate,
      'wallet_balance', v_wallet_balance,
      'issue_date', v_card.issue_date,
      'expiry_date', v_card.expiry_date,
      'status', v_card.status
    )
  );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION admin_issue_shark_card(uuid, text, text, text, text, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_shark_card(uuid) TO authenticated;