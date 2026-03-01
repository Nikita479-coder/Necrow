/*
  # Fix Shark Card System - All Column References

  1. Changes
    - Fix user_profiles references to use 'id' instead of 'user_id'
    - Fix notifications inserts to use correct column names: 'type' and 'read' instead of 'notification_type' and 'read_status'
    - Fix RLS policies that reference user_profiles.user_id
*/

-- Fix all RLS policies that reference user_profiles incorrectly
DROP POLICY IF EXISTS "Admins can view all card applications" ON shark_card_applications;
DROP POLICY IF EXISTS "Admins can update all card applications" ON shark_card_applications;
DROP POLICY IF EXISTS "Admins can view all cards" ON shark_cards;
DROP POLICY IF EXISTS "Admins can manage cards" ON shark_cards;
DROP POLICY IF EXISTS "Admins can view all card transactions" ON shark_card_transactions;

-- Recreate with correct column references
CREATE POLICY "Admins can view all card applications"
  ON shark_card_applications FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can update all card applications"
  ON shark_card_applications FOR UPDATE
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all cards"
  ON shark_cards FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can manage cards"
  ON shark_cards FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE id = auth.uid()));

CREATE POLICY "Admins can view all card transactions"
  ON shark_card_transactions FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE id = auth.uid()));

-- Recreate apply_for_shark_card with correct column names
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
  v_existing_app uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Check if user already has a pending or approved application
  SELECT application_id INTO v_existing_app
  FROM shark_card_applications
  WHERE user_id = v_user_id
    AND status IN ('pending', 'approved')
  LIMIT 1;
  
  IF v_existing_app IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You already have a pending or approved application');
  END IF;
  
  -- Create application
  INSERT INTO shark_card_applications (
    user_id, full_name, country, requested_limit
  )
  VALUES (
    v_user_id, p_full_name, p_country, p_requested_limit
  )
  RETURNING application_id INTO v_application_id;
  
  -- Create notification for admins using correct column names
  INSERT INTO notifications (user_id, type, title, message, read)
  SELECT 
    id,
    'shark_card_application',
    'New Shark Card Application',
    p_full_name || ' applied for a Shark Card with ' || p_requested_limit || ' USDT limit',
    false
  FROM user_profiles
  WHERE is_admin = true;
  
  RETURN jsonb_build_object(
    'success', true,
    'application_id', v_application_id,
    'message', 'Application submitted successfully'
  );
END;
$$;

-- Fix approve_shark_card_application
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
BEGIN
  v_admin_id := auth.uid();
  
  -- Check admin status using correct column name
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = v_admin_id;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Get application
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or already processed');
  END IF;
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'approved',
      reviewed_at = now(),
      reviewed_by = v_admin_id,
      notes = 'Approved with ' || p_approved_limit || ' USDT limit'
  WHERE application_id = p_application_id;
  
  -- Notify user with correct column names
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_application.user_id,
    'shark_card_approved',
    'Shark Card Application Approved!',
    'Your Shark Card application has been approved with a ' || p_approved_limit || ' USDT credit limit. Your card will be issued shortly.',
    false
  );
  
  RETURN jsonb_build_object('success', true, 'message', 'Application approved successfully');
END;
$$;

-- Fix decline_shark_card_application
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
BEGIN
  v_admin_id := auth.uid();
  
  -- Check admin status using correct column name
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = v_admin_id;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Get application
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or already processed');
  END IF;
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'declined',
      reviewed_at = now(),
      reviewed_by = v_admin_id,
      rejection_reason = p_reason
  WHERE application_id = p_application_id;
  
  -- Notify user with correct column names
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_application.user_id,
    'shark_card_declined',
    'Shark Card Application Update',
    'Your Shark Card application has been reviewed. ' || COALESCE(p_reason, 'Please contact support for more information.'),
    false
  );
  
  RETURN jsonb_build_object('success', true, 'message', 'Application declined');
END;
$$;

-- Fix issue_shark_card
CREATE OR REPLACE FUNCTION issue_shark_card(
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
  v_card_id uuid;
  v_card_number text;
  v_expiry_date timestamptz;
BEGIN
  v_admin_id := auth.uid();
  
  -- Check admin status using correct column name
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = v_admin_id;
  
  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  
  -- Get application
  SELECT * INTO v_application
  FROM shark_card_applications
  WHERE application_id = p_application_id
    AND status = 'approved';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Application not found or not approved');
  END IF;
  
  -- Generate card details
  v_card_number := generate_card_number();
  v_expiry_date := now() + interval '3 years';
  
  -- Create card
  INSERT INTO shark_cards (
    application_id,
    user_id,
    card_number,
    card_holder_name,
    credit_limit,
    available_credit,
    used_credit,
    cashback_rate,
    expiry_date,
    card_type,
    status
  )
  VALUES (
    p_application_id,
    v_application.user_id,
    v_card_number,
    v_application.full_name,
    p_approved_limit,
    p_approved_limit,
    0,
    p_cashback_rate,
    v_expiry_date,
    p_card_type,
    'active'
  )
  RETURNING card_id INTO v_card_id;
  
  -- Update application status
  UPDATE shark_card_applications
  SET status = 'issued'
  WHERE application_id = p_application_id;
  
  -- Notify user with correct column names
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_application.user_id,
    'shark_card_issued',
    'Your Shark Card Has Been Issued!',
    'Congratulations! Your Shark Card ending in ' || v_card_number || ' is now active with a ' || p_approved_limit || ' USDT credit limit and ' || p_cashback_rate || '% cashback.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'card_id', v_card_id,
    'card_number', v_card_number,
    'message', 'Card issued successfully'
  );
END;
$$;