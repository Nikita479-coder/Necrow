/*
  # Optimize RLS Policies - Batch 6 (More Tables)

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
*/

-- terms_and_conditions
DROP POLICY IF EXISTS "Admins can view all terms" ON terms_and_conditions;
CREATE POLICY "Admins can view all terms"
  ON terms_and_conditions FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert terms" ON terms_and_conditions;
CREATE POLICY "Admins can insert terms"
  ON terms_and_conditions FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update terms" ON terms_and_conditions;
CREATE POLICY "Admins can update terms"
  ON terms_and_conditions FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_terms_acceptance
DROP POLICY IF EXISTS "Admins can view all acceptances" ON user_terms_acceptance;
CREATE POLICY "Admins can view all acceptances"
  ON user_terms_acceptance FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- risk_scores
DROP POLICY IF EXISTS "Admins can view all risk scores" ON risk_scores;
CREATE POLICY "Admins can view all risk scores"
  ON risk_scores FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage risk scores" ON risk_scores;
CREATE POLICY "Admins can manage risk scores"
  ON risk_scores FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- risk_alerts
DROP POLICY IF EXISTS "Admins can view all risk alerts" ON risk_alerts;
CREATE POLICY "Admins can view all risk alerts"
  ON risk_alerts FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage risk alerts" ON risk_alerts;
CREATE POLICY "Admins can manage risk alerts"
  ON risk_alerts FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_risk_flags
DROP POLICY IF EXISTS "Admins can view user risk flags" ON user_risk_flags;
CREATE POLICY "Admins can view user risk flags"
  ON user_risk_flags FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage user risk flags" ON user_risk_flags;
CREATE POLICY "Admins can manage user risk flags"
  ON user_risk_flags FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- withdrawal_approvals
DROP POLICY IF EXISTS "Admins can view withdrawal approvals" ON withdrawal_approvals;
CREATE POLICY "Admins can view withdrawal approvals"
  ON withdrawal_approvals FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage withdrawal approvals" ON withdrawal_approvals;
CREATE POLICY "Admins can manage withdrawal approvals"
  ON withdrawal_approvals FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_device_fingerprints
DROP POLICY IF EXISTS "Admins can view device fingerprints" ON user_device_fingerprints;
CREATE POLICY "Admins can view device fingerprints"
  ON user_device_fingerprints FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage device fingerprints" ON user_device_fingerprints;
CREATE POLICY "Admins can manage device fingerprints"
  ON user_device_fingerprints FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- position_monitoring_logs
DROP POLICY IF EXISTS "Admins can view position monitoring logs" ON position_monitoring_logs;
CREATE POLICY "Admins can view position monitoring logs"
  ON position_monitoring_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create position monitoring logs" ON position_monitoring_logs;
CREATE POLICY "Admins can create position monitoring logs"
  ON position_monitoring_logs FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

-- risk_rules
DROP POLICY IF EXISTS "Admins can view risk rules" ON risk_rules;
CREATE POLICY "Admins can view risk rules"
  ON risk_rules FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage risk rules" ON risk_rules;
CREATE POLICY "Admins can manage risk rules"
  ON risk_rules FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- admin_activity_logs
DROP POLICY IF EXISTS "Admins can view admin activity logs" ON admin_activity_logs;
CREATE POLICY "Admins can view admin activity logs"
  ON admin_activity_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create admin activity logs" ON admin_activity_logs;
CREATE POLICY "Admins can create admin activity logs"
  ON admin_activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

-- security_logs
DROP POLICY IF EXISTS "Admins can view security logs" ON security_logs;
CREATE POLICY "Admins can view security logs"
  ON security_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- financial_transaction_logs
DROP POLICY IF EXISTS "Admins can view financial logs" ON financial_transaction_logs;
CREATE POLICY "Admins can view financial logs"
  ON financial_transaction_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- system_audit_logs
DROP POLICY IF EXISTS "Admins can view system audit logs" ON system_audit_logs;
CREATE POLICY "Admins can view system audit logs"
  ON system_audit_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- api_access_logs
DROP POLICY IF EXISTS "Admins can view API access logs" ON api_access_logs;
CREATE POLICY "Admins can view API access logs"
  ON api_access_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- data_export_logs
DROP POLICY IF EXISTS "Admins can view data export logs" ON data_export_logs;
CREATE POLICY "Admins can view data export logs"
  ON data_export_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create data export logs" ON data_export_logs;
CREATE POLICY "Admins can create data export logs"
  ON data_export_logs FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

-- kyc_action_logs
DROP POLICY IF EXISTS "Admins can view KYC action logs" ON kyc_action_logs;
CREATE POLICY "Admins can view KYC action logs"
  ON kyc_action_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create KYC action logs" ON kyc_action_logs;
CREATE POLICY "Admins can create KYC action logs"
  ON kyc_action_logs FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));
