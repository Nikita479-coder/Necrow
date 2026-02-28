/*
  # Create Comprehensive Logging System

  ## Description
  Complete audit trail and activity logging system for tracking all actions,
  security events, and system operations across the platform.

  ## New Tables

  ### 1. admin_activity_logs
  Track all admin actions
  - `id` (uuid, primary key)
  - `admin_id` (uuid) - Admin performing action
  - `action_type` (text) - Type of action
  - `action_description` (text) - Description
  - `target_user_id` (uuid) - Affected user
  - `ip_address` (text) - Admin IP
  - `metadata` (jsonb) - Additional details
  - `created_at` (timestamptz)

  ### 2. security_logs
  Security-related events
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User involved
  - `event_type` (text) - Event type
  - `severity` (text) - low, medium, high, critical
  - `ip_address` (text) - IP address
  - `device_fingerprint` (text) - Device ID
  - `success` (boolean) - Success status
  - `failure_reason` (text) - Failure reason
  - `metadata` (jsonb) - Additional data
  - `created_at` (timestamptz)

  ### 3. financial_transaction_logs
  All balance changes and financial operations
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User
  - `transaction_type` (text) - Type
  - `currency` (text) - Currency
  - `amount` (numeric) - Amount
  - `before_balance` (numeric) - Balance before
  - `after_balance` (numeric) - Balance after
  - `reference_id` (uuid) - Related record
  - `executed_by_admin_id` (uuid) - Admin (if manual)
  - `reason` (text) - Reason
  - `metadata` (jsonb) - Additional data
  - `created_at` (timestamptz)

  ### 4. system_audit_logs
  System-wide events
  - `id` (uuid, primary key)
  - `event_type` (text) - Event type
  - `severity` (text) - info, warning, error, critical
  - `description` (text) - Description
  - `affected_users_count` (integer) - Users affected
  - `triggered_by` (uuid) - User/admin who triggered
  - `metadata` (jsonb) - Additional data
  - `created_at` (timestamptz)

  ### 5. api_access_logs
  API endpoint access tracking
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User
  - `endpoint` (text) - API endpoint
  - `method` (text) - HTTP method
  - `status_code` (integer) - Response status
  - `response_time_ms` (integer) - Response time
  - `ip_address` (text) - IP address
  - `user_agent` (text) - Browser/client
  - `request_body` (jsonb) - Request data
  - `response_body` (jsonb) - Response data
  - `created_at` (timestamptz)

  ### 6. data_export_logs
  Track admin data exports
  - `id` (uuid, primary key)
  - `admin_id` (uuid) - Admin who exported
  - `export_type` (text) - Type of export
  - `filters_applied` (jsonb) - Filters used
  - `record_count` (integer) - Records exported
  - `file_url` (text) - Export file URL
  - `requested_at` (timestamptz)
  - `completed_at` (timestamptz)
  - `expires_at` (timestamptz)

  ### 7. kyc_action_logs
  KYC verification actions
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User
  - `admin_id` (uuid) - Admin
  - `action_type` (text) - Action type
  - `old_status` (text) - Previous status
  - `new_status` (text) - New status
  - `document_id` (uuid) - Related document
  - `reason` (text) - Reason
  - `notes` (text) - Admin notes
  - `created_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Admins have full read access
  - Write access controlled per table
  - Logs are immutable (no updates/deletes)

  ## Indexes
  - Optimized for filtering and searching
  - Time-based partitioning ready
*/

-- Admin Activity Logs Table
CREATE TABLE IF NOT EXISTS admin_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  action_type text NOT NULL,
  action_description text NOT NULL,
  target_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ip_address text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Security Logs Table
CREATE TABLE IF NOT EXISTS security_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'low',
  ip_address text,
  device_fingerprint text,
  success boolean NOT NULL DEFAULT true,
  failure_reason text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  CHECK (event_type IN ('login', 'login_failed', 'logout', '2fa_enabled', '2fa_disabled', '2fa_failed', 'password_change', 'email_change', 'suspicious_ip', 'brute_force_detected', 'account_locked', 'account_unlocked'))
);

-- Financial Transaction Logs Table
CREATE TABLE IF NOT EXISTS financial_transaction_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  transaction_type text NOT NULL,
  currency text NOT NULL,
  amount numeric(20,8) NOT NULL,
  before_balance numeric(20,8) NOT NULL,
  after_balance numeric(20,8) NOT NULL,
  reference_id uuid,
  executed_by_admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- System Audit Logs Table
CREATE TABLE IF NOT EXISTS system_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  description text NOT NULL,
  affected_users_count integer DEFAULT 0,
  triggered_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  CHECK (severity IN ('info', 'warning', 'error', 'critical'))
);

-- API Access Logs Table
CREATE TABLE IF NOT EXISTS api_access_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  endpoint text NOT NULL,
  method text NOT NULL,
  status_code integer NOT NULL,
  response_time_ms integer,
  ip_address text,
  user_agent text,
  request_body jsonb,
  response_body jsonb,
  created_at timestamptz DEFAULT now(),
  CHECK (method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH'))
);

-- Data Export Logs Table
CREATE TABLE IF NOT EXISTS data_export_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  export_type text NOT NULL,
  filters_applied jsonb DEFAULT '{}'::jsonb,
  record_count integer NOT NULL DEFAULT 0,
  file_url text,
  requested_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  expires_at timestamptz
);

-- KYC Action Logs Table
CREATE TABLE IF NOT EXISTS kyc_action_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type text NOT NULL,
  old_status text,
  new_status text,
  document_id uuid,
  reason text,
  notes text,
  created_at timestamptz DEFAULT now(),
  CHECK (action_type IN ('approve', 'reject', 'request_resubmission', 'upgrade_level', 'downgrade_level', 'manual_verification', 'document_reviewed'))
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_admin_id ON admin_activity_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_target_user ON admin_activity_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_created_at ON admin_activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_action_type ON admin_activity_logs(action_type);

CREATE INDEX IF NOT EXISTS idx_security_logs_user_id ON security_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_security_logs_event_type ON security_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_security_logs_severity ON security_logs(severity);
CREATE INDEX IF NOT EXISTS idx_security_logs_created_at ON security_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_logs_ip_address ON security_logs(ip_address);

CREATE INDEX IF NOT EXISTS idx_financial_logs_user_id ON financial_transaction_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_financial_logs_transaction_type ON financial_transaction_logs(transaction_type);
CREATE INDEX IF NOT EXISTS idx_financial_logs_currency ON financial_transaction_logs(currency);
CREATE INDEX IF NOT EXISTS idx_financial_logs_created_at ON financial_transaction_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_financial_logs_admin_id ON financial_transaction_logs(executed_by_admin_id);

CREATE INDEX IF NOT EXISTS idx_system_audit_logs_event_type ON system_audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_system_audit_logs_severity ON system_audit_logs(severity);
CREATE INDEX IF NOT EXISTS idx_system_audit_logs_created_at ON system_audit_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_api_access_logs_user_id ON api_access_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_api_access_logs_endpoint ON api_access_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_api_access_logs_created_at ON api_access_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_access_logs_status_code ON api_access_logs(status_code);

CREATE INDEX IF NOT EXISTS idx_data_export_logs_admin_id ON data_export_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_data_export_logs_requested_at ON data_export_logs(requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_kyc_action_logs_user_id ON kyc_action_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_action_logs_admin_id ON kyc_action_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_kyc_action_logs_created_at ON kyc_action_logs(created_at DESC);

-- Enable RLS
ALTER TABLE admin_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_transaction_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_access_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_export_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_action_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Admin read-only, system write)
CREATE POLICY "Admins can view admin activity logs"
  ON admin_activity_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can create admin activity logs"
  ON admin_activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    admin_id = auth.uid() AND
    ((auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  );

CREATE POLICY "Admins can view security logs"
  ON security_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "System can create security logs"
  ON security_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can view financial logs"
  ON financial_transaction_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "System can create financial logs"
  ON financial_transaction_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can view system audit logs"
  ON system_audit_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "System can create audit logs"
  ON system_audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can view API access logs"
  ON api_access_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "System can create API access logs"
  ON api_access_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can view data export logs"
  ON data_export_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can create data export logs"
  ON data_export_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    admin_id = auth.uid() AND
    ((auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  );

CREATE POLICY "Admins can view KYC action logs"
  ON kyc_action_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can create KYC action logs"
  ON kyc_action_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    admin_id = auth.uid() AND
    ((auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  );