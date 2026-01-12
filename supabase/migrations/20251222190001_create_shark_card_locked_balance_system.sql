/*
  # Shark Card Locked Balance System
  
  This migration implements a fund-locking mechanism for shark card applications.
  
  ## Changes Made
  
  ### 1. Schema Changes
  - Add `locked_amount` column to `shark_card_applications` to track locked funds per application
  - Allow multiple pending/approved applications per user (stacking locked amounts)
  
  ### 2. Function Updates
  
  #### apply_for_shark_card
  - Check if user has sufficient available balance (balance - locked_balance)
  - Lock the requested amount by moving from balance to locked_balance
  - Store locked amount in the application record
  - Allow multiple applications with stacked locked amounts
  
  #### approve_shark_card_application
  - Transfer locked funds immediately to shark card wallet on approval
  - Deduct from locked_balance, credit card wallet
  
  #### decline_shark_card_application
  - Unlock funds when application is declined
  - Move from locked_balance back to available balance
  
  #### cancel_shark_card_application (new)
  - Allow users to cancel their own pending applications
  - Unlock and return the locked funds
  
  ### 3. Security
  - All functions use SECURITY DEFINER with explicit search_path
  - Proper authentication checks
  - Transaction records for audit trail
  
  ## Important Notes
  - Locked funds are held during the review period
  - On approval: funds transfer to card wallet immediately
  - On decline: funds are unlocked and returned to user
  - Multiple applications stack their locked amounts
*/

-- Add locked_amount column to shark_card_applications
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_card_applications' AND column_name = 'locked_amount'
  ) THEN
    ALTER TABLE shark_card_applications ADD COLUMN locked_amount numeric(20,2) DEFAULT 0;
  END IF;
END $$;

-- Drop and recreate apply_for_shark_card function with locking logic
CREATE OR REPLACE FUNCTION apply_for_shark_card(
  p_full_name text,
  p_country text,
  p_requested_limit numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_application_id uuid;
  v_main_wallet_balance numeric;
  v_current_locked numeric;
  v_available_balance numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  IF p_requested_limit <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Requested limit must be greater than 0');
  END IF;
  
  -- Get user's main wallet USDT balance and locked balance
  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0) 
  INTO v_main_wallet_balance, v_current_locked
  FROM wallets
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'No USDT wallet found. Please deposit funds first.',
      'available_balance', 0
    );
  END IF;
  
  -- Calculate available balance (total balance minus already locked)
  v_available_balance := v_main_wallet_balance - v_current_locked;
  
  -- Check if user has sufficient available balance
  IF v_available_balance < p_requested_limit THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Insufficient available balance. You need ' || p_requested_limit || ' USDT but only have ' || ROUND(v_available_balance, 2) || ' USDT available.',
      'available_balance', v_available_balance,
      'required', p_requested_limit
    );
  END IF;
  
  -- Lock the funds by increasing locked_balance
  UPDATE wallets
  SET locked_balance = locked_balance + p_requested_limit,
      updated_at = now()
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';
  
  -- Create application with locked amount
  INSERT INTO shark_card_applications (
    user_id, full_name, country, requested_limit, locked_amount, status
  )
  VALUES (
    v_user_id, p_full_name, p_country, p_requested_limit, p_requested_limit, 'pending'
  )
  RETURNING application_id INTO v_application_id;
  
  -- Create transaction record for the lock
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  ) VALUES (
    v_user_id,
    'transfer',
    'USDT',
    p_requested_limit,
    'completed',
    'Funds locked for Shark Card application #' || v_application_id::text,
    now()
  );
  
  -- Create notification for admins
  INSERT INTO notifications (user_id, type, title, message, read)
  SELECT 
    up.user_id,
    'shark_card_application',
    'New Shark Card Application',
    p_full_name || ' applied for a Shark Card with ' || p_requested_limit || ' USDT limit (funds locked)',
    false
  FROM user_profiles up
  WHERE up.is_admin = true;
  
  -- Notify the user
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id,
    'shark_card_application',
    'Shark Card Application Submitted',
    'Your application for a ' || p_requested_limit || ' USDT Shark Card has been submitted. ' || p_requested_limit || ' USDT has been locked in your wallet pending review.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'application_id', v_application_id,
    'locked_amount', p_requested_limit,
    'message', 'Application submitted successfully. ' || p_requested_limit || ' USDT has been locked pending review.'
  );
END;
$$;

-- Update approve_shark_card_application to transfer locked funds to card wallet
CREATE OR REPLACE FUNCTION approve_shark_card_application(
  p_application_id uuid,
  p_approved_limit numeric,
  p_card_type text DEFAULT 'standard',
  p_cashback_rate numeric DEFAULT 1.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_application record;
  v_is_admin boolean;
  v_locked_amount numeric;
  v_difference numeric;
BEGIN
  v_admin_id := auth.uid();
  
  -- Check admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = v_admin_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Get application with lock
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or already processed');
  END IF;
  
  v_locked_amount := COALESCE(v_application.locked_amount, v_application.requested_limit);
  
  -- If approved limit differs from locked amount, handle the difference
  IF p_approved_limit > v_locked_amount THEN
    -- Cannot approve for more than what was locked
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Cannot approve for more than the locked amount (' || v_locked_amount || ' USDT)'
    );
  END IF;
  
  v_difference := v_locked_amount - p_approved_limit;
  
  -- Release any excess locked funds back to available balance
  IF v_difference > 0 THEN
    UPDATE wallets
    SET locked_balance = locked_balance - v_difference,
        updated_at = now()
    WHERE user_id = v_application.user_id 
      AND currency = 'USDT' 
      AND wallet_type = 'main';
  END IF;
  
  -- Transfer approved amount from locked_balance to card wallet
  -- First, deduct from locked_balance in main wallet
  UPDATE wallets
  SET locked_balance = locked_balance - p_approved_limit,
      balance = balance - p_approved_limit,
      updated_at = now()
  WHERE user_id = v_application.user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';
  
  -- Create or update card wallet with the approved amount
  INSERT INTO wallets (user_id, currency, balance, wallet_type, total_deposited)
  VALUES (v_application.user_id, 'USDT', p_approved_limit, 'card', p_approved_limit)
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET 
    balance = wallets.balance + p_approved_limit, 
    total_deposited = wallets.total_deposited + p_approved_limit,
    updated_at = now();
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'approved',
      reviewed_at = now(),
      reviewed_by = v_admin_id,
      notes = 'Approved with ' || p_approved_limit || ' USDT. Funds transferred to card wallet.'
  WHERE application_id = p_application_id;
  
  -- Create transaction record for the transfer
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  ) VALUES (
    v_application.user_id,
    'transfer',
    'USDT',
    p_approved_limit,
    'completed',
    'Shark Card approved - ' || p_approved_limit || ' USDT transferred to card wallet',
    now()
  );
  
  -- Notify user
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_application.user_id,
    'shark_card_approved',
    'Shark Card Application Approved!',
    'Your Shark Card application has been approved! ' || p_approved_limit || ' USDT has been transferred to your card wallet. Your card will be issued shortly.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Application approved. ' || p_approved_limit || ' USDT transferred to card wallet.',
    'approved_limit', p_approved_limit
  );
END;
$$;

-- Update decline_shark_card_application to unlock funds
CREATE OR REPLACE FUNCTION decline_shark_card_application(
  p_application_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_application record;
  v_is_admin boolean;
  v_locked_amount numeric;
BEGIN
  v_admin_id := auth.uid();
  
  -- Check admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = v_admin_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Get application with lock
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or already processed');
  END IF;
  
  v_locked_amount := COALESCE(v_application.locked_amount, v_application.requested_limit);
  
  -- Unlock the funds - move from locked_balance back to available
  UPDATE wallets
  SET locked_balance = GREATEST(locked_balance - v_locked_amount, 0),
      updated_at = now()
  WHERE user_id = v_application.user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'declined',
      reviewed_at = now(),
      reviewed_by = v_admin_id,
      rejection_reason = p_reason
  WHERE application_id = p_application_id;
  
  -- Create transaction record for the unlock
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  ) VALUES (
    v_application.user_id,
    'transfer',
    'USDT',
    v_locked_amount,
    'completed',
    'Shark Card application declined - ' || v_locked_amount || ' USDT unlocked and returned',
    now()
  );
  
  -- Notify user
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_application.user_id,
    'shark_card_declined',
    'Shark Card Application Update',
    'Your Shark Card application has been declined. ' || v_locked_amount || ' USDT has been unlocked and returned to your available balance. Reason: ' || COALESCE(p_reason, 'Not specified'),
    false
  );
  
  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Application declined. ' || v_locked_amount || ' USDT has been unlocked.',
    'unlocked_amount', v_locked_amount
  );
END;
$$;

-- Create function for users to cancel their own pending applications
CREATE OR REPLACE FUNCTION cancel_shark_card_application(
  p_application_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_application record;
  v_locked_amount numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Get application (must be owned by user and pending)
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND user_id = v_user_id
    AND status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or cannot be cancelled');
  END IF;
  
  v_locked_amount := COALESCE(v_application.locked_amount, v_application.requested_limit);
  
  -- Unlock the funds
  UPDATE wallets
  SET locked_balance = GREATEST(locked_balance - v_locked_amount, 0),
      updated_at = now()
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'main';
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'cancelled',
      updated_at = now()
  WHERE application_id = p_application_id;
  
  -- Create transaction record
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  ) VALUES (
    v_user_id,
    'transfer',
    'USDT',
    v_locked_amount,
    'completed',
    'Shark Card application cancelled - ' || v_locked_amount || ' USDT unlocked',
    now()
  );
  
  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Application cancelled. ' || v_locked_amount || ' USDT has been unlocked.',
    'unlocked_amount', v_locked_amount
  );
END;
$$;

-- Update admin_issue_shark_card to work with pre-transferred funds
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
  v_credit_limit numeric;
  v_application record;
BEGIN
  -- Check admin permissions
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
  END IF;

  -- Get approved application (funds already transferred to card wallet)
  SELECT * INTO v_application
  FROM shark_card_applications 
  WHERE application_id = p_application_id AND status = 'approved';

  IF v_application IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or not approved');
  END IF;

  v_user_id := v_application.user_id;
  v_credit_limit := COALESCE(v_application.locked_amount, v_application.requested_limit);

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

  -- Update application status
  UPDATE shark_card_applications 
  SET status = 'issued', 
      updated_at = now()
  WHERE application_id = p_application_id;

  -- Send notification to user
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id, 
    'shark_card_issued', 
    'Shark Card Issued!', 
    'Your Shark Card ending in ' || v_last_4 || ' has been issued with ' || v_credit_limit || ' USDT balance. You can now view your card details.', 
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
    'Issued Shark Card with ' || v_credit_limit || ' USDT (funds were pre-transferred on approval)', 
    v_user_id,
    jsonb_build_object(
      'card_id', v_card_id, 
      'application_id', p_application_id, 
      'card_type', p_card_type, 
      'last_4', v_last_4,
      'credit_limit', v_credit_limit
    )
  );

  RETURN jsonb_build_object(
    'success', true, 
    'card_id', v_card_id, 
    'message', 'Card issued successfully with ' || v_credit_limit || ' USDT balance.'
  );
END;
$$;
