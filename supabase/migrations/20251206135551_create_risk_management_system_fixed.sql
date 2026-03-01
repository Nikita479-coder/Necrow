/*
  # Create Risk Management System

  ## Description
  Comprehensive risk management and monitoring system for detecting suspicious
  activity, managing user risk profiles, and monitoring high-value operations.

  ## New Tables

  ### 1. risk_scores
  Overall user risk assessment
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User being scored
  - `overall_score` (numeric) - 0-100 risk score
  - `trading_score` (numeric) - Trading pattern score
  - `kyc_score` (numeric) - KYC verification score
  - `behavior_score` (numeric) - Behavior pattern score
  - `risk_level` (text) - low, medium, high, critical
  - `factors` (jsonb) - Detailed score breakdown
  - `last_calculated_at` (timestamptz)
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. risk_alerts
  Automated and manual risk alerts
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User with alert
  - `alert_type` (text) - Type of alert
  - `severity` (text) - low, medium, high, critical
  - `description` (text) - Alert description
  - `metadata` (jsonb) - Additional data
  - `is_auto_generated` (boolean) - Auto vs manual
  - `status` (text) - active, investigating, resolved, false_positive
  - `triggered_at` (timestamptz)
  - `acknowledged_at` (timestamptz)
  - `acknowledged_by_admin_id` (uuid) - Admin who acknowledged
  - `resolution_notes` (text)

  ### 3. user_risk_flags
  Manual risk flags applied by admins
  - `id` (uuid, primary key)
  - `user_id` (uuid) - Flagged user
  - `flag_type` (text) - Type of flag
  - `reason` (text) - Reason for flag
  - `flagged_by_admin_id` (uuid) - Admin who flagged
  - `is_active` (boolean)
  - `created_at` (timestamptz)
  - `expires_at` (timestamptz)

  ### 4. withdrawal_approvals
  Manual approval queue for high-value withdrawals
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User withdrawing
  - `transaction_id` (uuid) - Related transaction
  - `amount` (numeric) - Withdrawal amount
  - `currency` (text) - Currency
  - `destination_address` (text) - Withdrawal address
  - `risk_score` (numeric) - Calculated risk
  - `status` (text) - pending, approved, rejected
  - `auto_approved` (boolean)
  - `requested_at` (timestamptz)
  - `reviewed_at` (timestamptz)
  - `reviewed_by_admin_id` (uuid)
  - `review_notes` (text)

  ### 5. user_device_fingerprints
  Track user devices for fraud detection
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User
  - `device_id` (text) - Device fingerprint hash
  - `ip_address` (text) - IP address
  - `user_agent` (text) - Browser user agent
  - `location` (text) - Geographic location
  - `is_trusted` (boolean) - Trusted device
  - `first_seen_at` (timestamptz)
  - `last_seen_at` (timestamptz)
  - `login_count` (integer)

  ### 6. position_monitoring_logs
  Track large or risky positions
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User
  - `position_id` (uuid) - Related position
  - `event_type` (text) - Event type
  - `details` (jsonb) - Event details
  - `notified_admin` (boolean) - Admin notified
  - `created_at` (timestamptz)

  ### 7. risk_rules
  Automated risk detection rules
  - `id` (uuid, primary key)
  - `rule_name` (text) - Rule name
  - `rule_type` (text) - Type of rule
  - `conditions` (jsonb) - Rule conditions
  - `actions` (jsonb) - Actions to take
  - `severity` (text) - Alert severity
  - `is_active` (boolean)
  - `created_by_admin_id` (uuid)
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Only admins can access risk management data
  - Comprehensive audit trail

  ## Indexes
  - Optimized for alert filtering and user lookup
*/

-- Risk Scores Table
CREATE TABLE IF NOT EXISTS risk_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  overall_score numeric(5,2) NOT NULL DEFAULT 0,
  trading_score numeric(5,2) NOT NULL DEFAULT 0,
  kyc_score numeric(5,2) NOT NULL DEFAULT 0,
  behavior_score numeric(5,2) NOT NULL DEFAULT 0,
  risk_level text NOT NULL DEFAULT 'low',
  factors jsonb DEFAULT '{}'::jsonb,
  last_calculated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  CHECK (overall_score >= 0 AND overall_score <= 100)
);

-- Risk Alerts Table
CREATE TABLE IF NOT EXISTS risk_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  alert_type text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  description text NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  is_auto_generated boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active',
  triggered_at timestamptz DEFAULT now(),
  acknowledged_at timestamptz,
  acknowledged_by_admin_id uuid REFERENCES auth.users(id),
  resolution_notes text,
  CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  CHECK (status IN ('active', 'investigating', 'resolved', 'false_positive'))
);

-- User Risk Flags Table
CREATE TABLE IF NOT EXISTS user_risk_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  flag_type text NOT NULL,
  reason text NOT NULL,
  flagged_by_admin_id uuid REFERENCES auth.users(id) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  CHECK (flag_type IN ('suspicious_activity', 'multiple_accounts', 'high_velocity', 'whale', 'vip', 'fraud_suspected', 'under_investigation'))
);

-- Withdrawal Approvals Table
CREATE TABLE IF NOT EXISTS withdrawal_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  transaction_id uuid,
  amount numeric(20,8) NOT NULL,
  currency text NOT NULL,
  destination_address text NOT NULL,
  risk_score numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  auto_approved boolean NOT NULL DEFAULT false,
  requested_at timestamptz DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by_admin_id uuid REFERENCES auth.users(id),
  review_notes text,
  CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- User Device Fingerprints Table
CREATE TABLE IF NOT EXISTS user_device_fingerprints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  device_id text NOT NULL,
  ip_address text NOT NULL,
  user_agent text,
  location text,
  is_trusted boolean NOT NULL DEFAULT false,
  first_seen_at timestamptz DEFAULT now(),
  last_seen_at timestamptz DEFAULT now(),
  login_count integer NOT NULL DEFAULT 1,
  UNIQUE(user_id, device_id)
);

-- Position Monitoring Logs Table
CREATE TABLE IF NOT EXISTS position_monitoring_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  position_id uuid,
  event_type text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  notified_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  CHECK (event_type IN ('large_position_opened', 'margin_warning', 'liquidation_risk', 'unusual_pnl', 'high_leverage'))
);

-- Risk Rules Table
CREATE TABLE IF NOT EXISTS risk_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name text NOT NULL UNIQUE,
  rule_type text NOT NULL,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  actions jsonb NOT NULL DEFAULT '{}'::jsonb,
  severity text NOT NULL DEFAULT 'medium',
  is_active boolean NOT NULL DEFAULT true,
  created_by_admin_id uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  CHECK (rule_type IN ('deposit', 'withdrawal', 'trading', 'login', 'kyc', 'custom'))
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_risk_scores_user_id ON risk_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_scores_risk_level ON risk_scores(risk_level);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_user_id ON risk_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_status ON risk_alerts(status);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_severity ON risk_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_risk_alerts_triggered_at ON risk_alerts(triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_risk_flags_user_id ON user_risk_flags(user_id);
CREATE INDEX IF NOT EXISTS idx_user_risk_flags_active ON user_risk_flags(is_active);
CREATE INDEX IF NOT EXISTS idx_withdrawal_approvals_status ON withdrawal_approvals(status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_approvals_user_id ON withdrawal_approvals(user_id);
CREATE INDEX IF NOT EXISTS idx_device_fingerprints_user_id ON user_device_fingerprints(user_id);
CREATE INDEX IF NOT EXISTS idx_device_fingerprints_device_id ON user_device_fingerprints(device_id);
CREATE INDEX IF NOT EXISTS idx_position_monitoring_user_id ON position_monitoring_logs(user_id);

-- Enable RLS
ALTER TABLE risk_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_risk_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_device_fingerprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE position_monitoring_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_rules ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Admin-only access)
CREATE POLICY "Admins can view all risk scores"
  ON risk_scores FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage risk scores"
  ON risk_scores FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view all risk alerts"
  ON risk_alerts FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage risk alerts"
  ON risk_alerts FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view user risk flags"
  ON user_risk_flags FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage user risk flags"
  ON user_risk_flags FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view withdrawal approvals"
  ON withdrawal_approvals FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage withdrawal approvals"
  ON withdrawal_approvals FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view device fingerprints"
  ON user_device_fingerprints FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage device fingerprints"
  ON user_device_fingerprints FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view position monitoring logs"
  ON position_monitoring_logs FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can create position monitoring logs"
  ON position_monitoring_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can view risk rules"
  ON risk_rules FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage risk rules"
  ON risk_rules FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Initialize risk scores for existing users
INSERT INTO risk_scores (user_id, overall_score, trading_score, kyc_score, behavior_score, risk_level)
SELECT 
  up.id,
  CASE 
    WHEN up.kyc_status = 'verified' THEN 20
    WHEN up.kyc_status = 'pending' THEN 40
    ELSE 60
  END as overall_score,
  30 as trading_score,
  CASE 
    WHEN up.kyc_status = 'verified' THEN 10
    WHEN up.kyc_status = 'pending' THEN 40
    ELSE 70
  END as kyc_score,
  25 as behavior_score,
  CASE 
    WHEN up.kyc_status = 'verified' THEN 'low'
    WHEN up.kyc_status = 'pending' THEN 'medium'
    ELSE 'high'
  END as risk_level
FROM user_profiles up
ON CONFLICT (user_id) DO NOTHING;