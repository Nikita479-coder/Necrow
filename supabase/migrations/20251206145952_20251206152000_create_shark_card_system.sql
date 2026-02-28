/*
  # Shark Card Credit Card System

  1. New Tables
    - `shark_card_applications`
      - `application_id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `full_name` (text) - Applicant's full legal name
      - `country` (text) - Country of residence
      - `requested_limit` (numeric) - Requested credit limit in USDT
      - `status` (text) - pending, approved, declined, issued, cancelled
      - `application_date` (timestamptz)
      - `reviewed_at` (timestamptz)
      - `reviewed_by` (uuid) - Admin who reviewed
      - `rejection_reason` (text)
      - `notes` (text) - Admin notes
      
    - `shark_cards`
      - `card_id` (uuid, primary key)
      - `application_id` (uuid, references shark_card_applications)
      - `user_id` (uuid, references auth.users)
      - `card_number` (text) - Last 4 digits only for display
      - `card_holder_name` (text)
      - `credit_limit` (numeric)
      - `available_credit` (numeric)
      - `used_credit` (numeric)
      - `cashback_rate` (numeric) - Percentage cashback
      - `issue_date` (timestamptz)
      - `expiry_date` (timestamptz)
      - `status` (text) - active, suspended, closed
      - `card_type` (text) - standard, gold, platinum
      
    - `shark_card_transactions`
      - `transaction_id` (uuid, primary key)
      - `card_id` (uuid, references shark_cards)
      - `user_id` (uuid)
      - `amount` (numeric)
      - `transaction_type` (text) - purchase, payment, cashback, fee
      - `description` (text)
      - `merchant` (text)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Users can view their own applications and cards
    - Admins can view and manage all applications
    - Card numbers are encrypted/masked
*/

-- Shark Card Applications Table
CREATE TABLE IF NOT EXISTS shark_card_applications (
  application_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  full_name text NOT NULL,
  country text NOT NULL,
  requested_limit numeric(20,2) NOT NULL CHECK (requested_limit > 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'issued', 'cancelled')),
  application_date timestamptz DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id),
  rejection_reason text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Shark Cards Table
CREATE TABLE IF NOT EXISTS shark_cards (
  card_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid REFERENCES shark_card_applications(application_id),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  card_number text NOT NULL,
  card_holder_name text NOT NULL,
  credit_limit numeric(20,2) NOT NULL CHECK (credit_limit > 0),
  available_credit numeric(20,2) NOT NULL DEFAULT 0,
  used_credit numeric(20,2) NOT NULL DEFAULT 0,
  cashback_rate numeric(5,2) DEFAULT 1.0 CHECK (cashback_rate >= 0 AND cashback_rate <= 100),
  issue_date timestamptz DEFAULT now(),
  expiry_date timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
  card_type text NOT NULL DEFAULT 'standard' CHECK (card_type IN ('standard', 'gold', 'platinum')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Shark Card Transactions Table
CREATE TABLE IF NOT EXISTS shark_card_transactions (
  transaction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id uuid REFERENCES shark_cards(card_id) NOT NULL,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  amount numeric(20,2) NOT NULL,
  transaction_type text NOT NULL CHECK (transaction_type IN ('purchase', 'payment', 'cashback', 'fee', 'refund')),
  description text NOT NULL,
  merchant text,
  balance_after numeric(20,2),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE shark_card_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE shark_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE shark_card_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for shark_card_applications

-- Users can view their own applications
CREATE POLICY "Users can view own card applications"
  ON shark_card_applications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create their own applications
CREATE POLICY "Users can create own card applications"
  ON shark_card_applications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can cancel their pending applications
CREATE POLICY "Users can cancel own pending applications"
  ON shark_card_applications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (auth.uid() = user_id AND status IN ('pending', 'cancelled'));

-- Admins can view all applications
CREATE POLICY "Admins can view all card applications"
  ON shark_card_applications FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()));

-- Admins can update all applications
CREATE POLICY "Admins can update all card applications"
  ON shark_card_applications FOR UPDATE
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()));

-- RLS Policies for shark_cards

-- Users can view their own cards
CREATE POLICY "Users can view own cards"
  ON shark_cards FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all cards
CREATE POLICY "Admins can view all cards"
  ON shark_cards FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()));

-- Admins can create and manage cards
CREATE POLICY "Admins can manage cards"
  ON shark_cards FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()));

-- RLS Policies for shark_card_transactions

-- Users can view their own transactions
CREATE POLICY "Users can view own card transactions"
  ON shark_card_transactions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all transactions
CREATE POLICY "Admins can view all card transactions"
  ON shark_card_transactions FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'role' = 'admin') OR (SELECT is_admin FROM user_profiles WHERE user_id = auth.uid()));

-- Indexes
CREATE INDEX IF NOT EXISTS idx_card_applications_user_id ON shark_card_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_card_applications_status ON shark_card_applications(status);
CREATE INDEX IF NOT EXISTS idx_card_applications_date ON shark_card_applications(application_date DESC);

CREATE INDEX IF NOT EXISTS idx_shark_cards_user_id ON shark_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_shark_cards_status ON shark_cards(status);

CREATE INDEX IF NOT EXISTS idx_card_transactions_card_id ON shark_card_transactions(card_id);
CREATE INDEX IF NOT EXISTS idx_card_transactions_user_id ON shark_card_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_card_transactions_date ON shark_card_transactions(created_at DESC);

-- Function to generate card number (last 4 digits for display)
CREATE OR REPLACE FUNCTION generate_card_number()
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN LPAD(FLOOR(RANDOM() * 10000)::text, 4, '0');
END;
$$;

-- Function to apply for Shark Card
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
  
  -- Create notification for admins
  INSERT INTO notifications (user_id, notification_type, title, message, read_status)
  SELECT 
    user_id,
    'shark_card_application',
    'New Shark Card Application',
    p_full_name || ' applied for a Shark Card with ' || p_requested_limit || ' USDT limit',
    'unread'
  FROM user_profiles
  WHERE is_admin = true;
  
  RETURN jsonb_build_object(
    'success', true,
    'application_id', v_application_id,
    'message', 'Application submitted successfully'
  );
END;
$$;

-- Function to approve Shark Card application
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
  
  -- Check admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = v_admin_id;
  
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
  
  -- Notify user
  INSERT INTO notifications (user_id, notification_type, title, message, read_status)
  VALUES (
    v_application.user_id,
    'shark_card_approved',
    'Shark Card Application Approved!',
    'Your Shark Card application has been approved with a ' || p_approved_limit || ' USDT credit limit. Your card will be issued shortly.',
    'unread'
  );
  
  RETURN jsonb_build_object('success', true, 'message', 'Application approved successfully');
END;
$$;

-- Function to decline Shark Card application
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
  
  -- Check admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = v_admin_id;
  
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
  
  -- Notify user
  INSERT INTO notifications (user_id, notification_type, title, message, read_status)
  VALUES (
    v_application.user_id,
    'shark_card_declined',
    'Shark Card Application Update',
    'Your Shark Card application has been reviewed. ' || COALESCE(p_reason, 'Please contact support for more information.'),
    'unread'
  );
  
  RETURN jsonb_build_object('success', true, 'message', 'Application declined');
END;
$$;

-- Function to issue Shark Card
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
  
  -- Check admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = v_admin_id;
  
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
  
  -- Notify user
  INSERT INTO notifications (user_id, notification_type, title, message, read_status)
  VALUES (
    v_application.user_id,
    'shark_card_issued',
    'Your Shark Card Has Been Issued!',
    'Congratulations! Your Shark Card ending in ' || v_card_number || ' is now active with a ' || p_approved_limit || ' USDT credit limit and ' || p_cashback_rate || '% cashback.',
    'unread'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'card_id', v_card_id,
    'card_number', v_card_number,
    'message', 'Card issued successfully'
  );
END;
$$;