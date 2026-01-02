/*
  # Phone Reveal Request System and Staff Activity Logging

  ## Overview
  Creates a comprehensive system for:
  1. Masking phone numbers from non-super-admin staff
  2. Phone reveal request workflow (request -> approve/deny)
  3. Detailed staff activity logging for CRM actions

  ## New Tables

  ### 1. `phone_reveal_requests`
  - Tracks requests from staff to reveal masked phone numbers
  - Columns: id, requester_id, target_user_id, reason, status, reviewed_by, reviewed_at, admin_notes

  ### 2. `phone_reveals_granted`
  - Tracks approved reveals with optional expiration
  - Allows staff to view specific phone numbers after approval

  ### 3. `staff_activity_logs`
  - Comprehensive logging of all staff CRM actions
  - Tracks page views, user profile views, searches, actions taken

  ## New Permissions
  - `view_phones_masked` - See phone numbers with masking (last 4 digits only)
  - `view_phones_full` - See full phone numbers (super admin only)
  - `request_phone_reveal` - Can submit phone reveal requests
  - `manage_phone_reveals` - Can approve or deny phone reveal requests

  ## Security
  - All tables have RLS enabled
  - Staff can only see their own requests
  - Super admins can see all requests and logs
*/

-- Phone reveal requests table
CREATE TABLE IF NOT EXISTS phone_reveal_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  admin_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Phone reveals granted table (tracks approved reveals)
CREATE TABLE IF NOT EXISTS phone_reveals_granted (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  granted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid REFERENCES phone_reveal_requests(id) ON DELETE SET NULL,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(staff_id, target_user_id)
);

-- Staff activity logs table
CREATE TABLE IF NOT EXISTS staff_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  action_description text NOT NULL,
  target_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  page_visited text,
  search_query text,
  ip_address text,
  user_agent text,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_phone_reveal_requests_requester ON phone_reveal_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_phone_reveal_requests_status ON phone_reveal_requests(status);
CREATE INDEX IF NOT EXISTS idx_phone_reveal_requests_created ON phone_reveal_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_phone_reveals_granted_staff ON phone_reveals_granted(staff_id);
CREATE INDEX IF NOT EXISTS idx_phone_reveals_granted_target ON phone_reveals_granted(target_user_id);
CREATE INDEX IF NOT EXISTS idx_staff_activity_logs_staff ON staff_activity_logs(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_activity_logs_created ON staff_activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_staff_activity_logs_action ON staff_activity_logs(action_type);

-- Enable RLS
ALTER TABLE phone_reveal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE phone_reveals_granted ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_activity_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for phone_reveal_requests
CREATE POLICY "Staff can view their own requests"
  ON phone_reveal_requests FOR SELECT
  TO authenticated
  USING (requester_id = auth.uid());

CREATE POLICY "Super admins can view all requests"
  ON phone_reveal_requests FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Staff can create requests"
  ON phone_reveal_requests FOR INSERT
  TO authenticated
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Super admins can update requests"
  ON phone_reveal_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- RLS Policies for phone_reveals_granted
CREATE POLICY "Staff can view their own grants"
  ON phone_reveals_granted FOR SELECT
  TO authenticated
  USING (staff_id = auth.uid());

CREATE POLICY "Super admins can view all grants"
  ON phone_reveals_granted FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Super admins can manage grants"
  ON phone_reveals_granted FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- RLS Policies for staff_activity_logs
CREATE POLICY "Super admins can view all staff logs"
  ON staff_activity_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Staff can insert their own logs"
  ON staff_activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (staff_id = auth.uid());

-- Add new permissions to admin_permissions table
INSERT INTO admin_permissions (code, name, description, category)
VALUES
  ('view_phones_masked', 'View Masked Phones', 'View phone numbers with masking (last 4 digits only)', 'crm'),
  ('view_phones_full', 'View Full Phones', 'View full phone numbers without masking', 'crm'),
  ('request_phone_reveal', 'Request Phone Reveal', 'Can submit requests to reveal masked phone numbers', 'crm'),
  ('manage_phone_reveals', 'Manage Phone Reveals', 'Can approve or deny phone reveal requests', 'crm'),
  ('view_staff_activity', 'View Staff Activity', 'Can view staff activity logs', 'admin')
ON CONFLICT (code) DO NOTHING;

-- Function to check if staff has reveal access for a specific user
CREATE OR REPLACE FUNCTION check_phone_reveal_access(p_staff_id uuid, p_target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_super_admin boolean;
  v_has_grant boolean;
BEGIN
  -- Check if super admin (they always have access)
  SELECT is_admin INTO v_is_super_admin
  FROM user_profiles
  WHERE id = p_staff_id;
  
  IF v_is_super_admin = true THEN
    RETURN true;
  END IF;
  
  -- Check if there's a valid (non-expired) grant
  SELECT EXISTS (
    SELECT 1 FROM phone_reveals_granted
    WHERE staff_id = p_staff_id
    AND target_user_id = p_target_user_id
    AND (expires_at IS NULL OR expires_at > now())
  ) INTO v_has_grant;
  
  RETURN v_has_grant;
END;
$$;

-- Function to get phone number (masked or full based on access)
CREATE OR REPLACE FUNCTION get_user_phone_for_staff(p_staff_id uuid, p_target_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone text;
  v_has_access boolean;
BEGIN
  -- Get the phone number
  SELECT phone INTO v_phone
  FROM user_profiles
  WHERE id = p_target_user_id;
  
  IF v_phone IS NULL OR v_phone = '' THEN
    RETURN NULL;
  END IF;
  
  -- Check access
  v_has_access := check_phone_reveal_access(p_staff_id, p_target_user_id);
  
  IF v_has_access THEN
    RETURN v_phone;
  ELSE
    -- Return masked version (show only last 4 digits)
    IF length(v_phone) > 4 THEN
      RETURN repeat('*', length(v_phone) - 4) || right(v_phone, 4);
    ELSE
      RETURN '****';
    END IF;
  END IF;
END;
$$;

-- Function to create phone reveal request
CREATE OR REPLACE FUNCTION create_phone_reveal_request(
  p_target_user_id uuid,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request_id uuid;
  v_requester_id uuid := auth.uid();
BEGIN
  -- Check if there's already a pending request
  IF EXISTS (
    SELECT 1 FROM phone_reveal_requests
    WHERE requester_id = v_requester_id
    AND target_user_id = p_target_user_id
    AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'You already have a pending request for this user';
  END IF;
  
  -- Create the request
  INSERT INTO phone_reveal_requests (requester_id, target_user_id, reason)
  VALUES (v_requester_id, p_target_user_id, p_reason)
  RETURNING id INTO v_request_id;
  
  -- Log the activity
  INSERT INTO staff_activity_logs (staff_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_requester_id,
    'phone_reveal_request',
    'Requested access to view phone number',
    p_target_user_id,
    jsonb_build_object('reason', p_reason, 'request_id', v_request_id)
  );
  
  -- Create notification for super admins
  INSERT INTO notifications (user_id, type, title, message, data)
  SELECT 
    up.id,
    'system',
    'Phone Reveal Request',
    'A staff member has requested access to view a user phone number',
    jsonb_build_object('request_id', v_request_id, 'requester_id', v_requester_id)
  FROM user_profiles up
  WHERE up.is_admin = true;
  
  RETURN v_request_id;
END;
$$;

-- Function to process phone reveal request (approve/deny)
CREATE OR REPLACE FUNCTION process_phone_reveal_request(
  p_request_id uuid,
  p_action text,
  p_admin_notes text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_is_admin boolean;
  v_request record;
BEGIN
  -- Verify admin status
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = v_admin_id;
  
  IF v_is_admin IS NOT true THEN
    RAISE EXCEPTION 'Only super admins can process phone reveal requests';
  END IF;
  
  -- Get request details
  SELECT * INTO v_request
  FROM phone_reveal_requests
  WHERE id = p_request_id;
  
  IF v_request IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  
  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Request has already been processed';
  END IF;
  
  -- Update the request
  UPDATE phone_reveal_requests
  SET 
    status = p_action,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    admin_notes = p_admin_notes,
    updated_at = now()
  WHERE id = p_request_id;
  
  -- If approved, grant access
  IF p_action = 'approved' THEN
    INSERT INTO phone_reveals_granted (staff_id, target_user_id, granted_by, request_id)
    VALUES (v_request.requester_id, v_request.target_user_id, v_admin_id, p_request_id)
    ON CONFLICT (staff_id, target_user_id) DO UPDATE SET
      granted_by = v_admin_id,
      request_id = p_request_id,
      expires_at = NULL,
      created_at = now();
  END IF;
  
  -- Log the admin action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_admin_id,
    'phone_reveal_' || p_action,
    CASE p_action 
      WHEN 'approved' THEN 'Approved phone reveal request'
      ELSE 'Denied phone reveal request'
    END,
    v_request.target_user_id,
    jsonb_build_object(
      'request_id', p_request_id,
      'requester_id', v_request.requester_id,
      'admin_notes', p_admin_notes
    )
  );
  
  -- Notify the requester
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_request.requester_id,
    'system',
    'Phone Reveal Request ' || initcap(p_action),
    CASE p_action 
      WHEN 'approved' THEN 'Your request to view a user phone number has been approved'
      ELSE 'Your request to view a user phone number has been denied'
    END,
    jsonb_build_object('request_id', p_request_id, 'status', p_action)
  );
  
  RETURN true;
END;
$$;

-- Function to log staff activity
CREATE OR REPLACE FUNCTION log_staff_activity(
  p_action_type text,
  p_action_description text,
  p_target_user_id uuid DEFAULT NULL,
  p_page_visited text DEFAULT NULL,
  p_search_query text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO staff_activity_logs (
    staff_id,
    action_type,
    action_description,
    target_user_id,
    page_visited,
    search_query,
    metadata
  )
  VALUES (
    auth.uid(),
    p_action_type,
    p_action_description,
    p_target_user_id,
    p_page_visited,
    p_search_query,
    p_metadata
  );
END;
$$;

-- Function to get staff activity logs (super admin only)
CREATE OR REPLACE FUNCTION get_staff_activity_logs(
  p_staff_id uuid DEFAULT NULL,
  p_action_type text DEFAULT NULL,
  p_from_date timestamptz DEFAULT NULL,
  p_to_date timestamptz DEFAULT NULL,
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  staff_id uuid,
  staff_name text,
  staff_email text,
  action_type text,
  action_description text,
  target_user_id uuid,
  target_user_name text,
  page_visited text,
  search_query text,
  ip_address text,
  metadata jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  -- Verify admin status
  SELECT up.is_admin INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = auth.uid();
  
  IF v_is_admin IS NOT true THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    sal.id,
    sal.staff_id,
    staff_profile.full_name as staff_name,
    COALESCE(staff_auth.email, '') as staff_email,
    sal.action_type,
    sal.action_description,
    sal.target_user_id,
    target_profile.full_name as target_user_name,
    sal.page_visited,
    sal.search_query,
    sal.ip_address,
    sal.metadata,
    sal.created_at
  FROM staff_activity_logs sal
  LEFT JOIN user_profiles staff_profile ON staff_profile.id = sal.staff_id
  LEFT JOIN auth.users staff_auth ON staff_auth.id = sal.staff_id
  LEFT JOIN user_profiles target_profile ON target_profile.id = sal.target_user_id
  WHERE (p_staff_id IS NULL OR sal.staff_id = p_staff_id)
    AND (p_action_type IS NULL OR sal.action_type = p_action_type)
    AND (p_from_date IS NULL OR sal.created_at >= p_from_date)
    AND (p_to_date IS NULL OR sal.created_at <= p_to_date)
  ORDER BY sal.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Function to get pending phone reveal requests count
CREATE OR REPLACE FUNCTION get_pending_phone_reveal_count()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  v_count int;
BEGIN
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF v_is_admin IS NOT true THEN
    RETURN 0;
  END IF;
  
  SELECT COUNT(*) INTO v_count
  FROM phone_reveal_requests
  WHERE status = 'pending';
  
  RETURN v_count;
END;
$$;

-- Function to get all phone reveal requests (for admin)
CREATE OR REPLACE FUNCTION get_phone_reveal_requests(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  requester_id uuid,
  requester_name text,
  requester_email text,
  target_user_id uuid,
  target_user_name text,
  target_user_phone text,
  reason text,
  status text,
  reviewed_by uuid,
  reviewer_name text,
  reviewed_at timestamptz,
  admin_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  SELECT up.is_admin INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = auth.uid();
  
  IF v_is_admin IS NOT true THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    prr.id,
    prr.requester_id,
    req_profile.full_name as requester_name,
    COALESCE(req_auth.email, '') as requester_email,
    prr.target_user_id,
    target_profile.full_name as target_user_name,
    target_profile.phone as target_user_phone,
    prr.reason,
    prr.status,
    prr.reviewed_by,
    reviewer_profile.full_name as reviewer_name,
    prr.reviewed_at,
    prr.admin_notes,
    prr.created_at
  FROM phone_reveal_requests prr
  LEFT JOIN user_profiles req_profile ON req_profile.id = prr.requester_id
  LEFT JOIN auth.users req_auth ON req_auth.id = prr.requester_id
  LEFT JOIN user_profiles target_profile ON target_profile.id = prr.target_user_id
  LEFT JOIN user_profiles reviewer_profile ON reviewer_profile.id = prr.reviewed_by
  WHERE (p_status IS NULL OR prr.status = p_status)
  ORDER BY 
    CASE prr.status WHEN 'pending' THEN 0 ELSE 1 END,
    prr.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
