/*
  # Optimize RLS Policies - Batch 4 (Admin & User Tables)

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
*/

-- user_sessions
DROP POLICY IF EXISTS "Users can view own session" ON user_sessions;
CREATE POLICY "Users can view own session"
  ON user_sessions FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own session" ON user_sessions;
CREATE POLICY "Users can update own session"
  ON user_sessions FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own session" ON user_sessions;
CREATE POLICY "Users can insert own session"
  ON user_sessions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all sessions" ON user_sessions;
CREATE POLICY "Admins can view all sessions"
  ON user_sessions FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_activity_log
DROP POLICY IF EXISTS "Admins can view all activity" ON user_activity_log;
CREATE POLICY "Admins can view all activity"
  ON user_activity_log FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_acquisition_sources
DROP POLICY IF EXISTS "Users can view own acquisition data" ON user_acquisition_sources;
CREATE POLICY "Users can view own acquisition data"
  ON user_acquisition_sources FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own acquisition data" ON user_acquisition_sources;
CREATE POLICY "Users can insert own acquisition data"
  ON user_acquisition_sources FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all acquisition data" ON user_acquisition_sources;
CREATE POLICY "Admins can view all acquisition data"
  ON user_acquisition_sources FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- acquisition_events
DROP POLICY IF EXISTS "Users can view own events" ON acquisition_events;
CREATE POLICY "Users can view own events"
  ON acquisition_events FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own events" ON acquisition_events;
CREATE POLICY "Users can insert own events"
  ON acquisition_events FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all events" ON acquisition_events;
CREATE POLICY "Admins can view all events"
  ON acquisition_events FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- email_templates
DROP POLICY IF EXISTS "Admins can view all email templates" ON email_templates;
CREATE POLICY "Admins can view all email templates"
  ON email_templates FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create email templates" ON email_templates;
CREATE POLICY "Admins can create email templates"
  ON email_templates FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update email templates" ON email_templates;
CREATE POLICY "Admins can update email templates"
  ON email_templates FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can delete email templates" ON email_templates;
CREATE POLICY "Admins can delete email templates"
  ON email_templates FOR DELETE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- email_logs
DROP POLICY IF EXISTS "Admins can view all email logs" ON email_logs;
CREATE POLICY "Admins can view all email logs"
  ON email_logs FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert email logs" ON email_logs;
CREATE POLICY "Admins can insert email logs"
  ON email_logs FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

-- bonus_types
DROP POLICY IF EXISTS "Admins can view all bonus types" ON bonus_types;
CREATE POLICY "Admins can view all bonus types"
  ON bonus_types FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can create bonus types" ON bonus_types;
CREATE POLICY "Admins can create bonus types"
  ON bonus_types FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update bonus types" ON bonus_types;
CREATE POLICY "Admins can update bonus types"
  ON bonus_types FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can delete bonus types" ON bonus_types;
CREATE POLICY "Admins can delete bonus types"
  ON bonus_types FOR DELETE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_bonuses
DROP POLICY IF EXISTS "Admins can view all user bonuses" ON user_bonuses;
CREATE POLICY "Admins can view all user bonuses"
  ON user_bonuses FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert user bonuses" ON user_bonuses;
CREATE POLICY "Admins can insert user bonuses"
  ON user_bonuses FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update user bonuses" ON user_bonuses;
CREATE POLICY "Admins can update user bonuses"
  ON user_bonuses FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));
