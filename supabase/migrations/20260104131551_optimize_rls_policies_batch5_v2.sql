/*
  # Optimize RLS Policies - Batch 5 (Support, KYC, More) - Fixed

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
*/

-- support_categories
DROP POLICY IF EXISTS "Admins can manage support categories" ON support_categories;
CREATE POLICY "Admins can manage support categories"
  ON support_categories FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- support_tickets
DROP POLICY IF EXISTS "Users can create support tickets" ON support_tickets;
CREATE POLICY "Users can create support tickets"
  ON support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can view own support tickets" ON support_tickets;
CREATE POLICY "Users can view own support tickets"
  ON support_tickets FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own support tickets" ON support_tickets;
CREATE POLICY "Users can update own support tickets"
  ON support_tickets FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all support tickets" ON support_tickets;
CREATE POLICY "Admins can manage all support tickets"
  ON support_tickets FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- support_messages
DROP POLICY IF EXISTS "Users can view messages from own tickets" ON support_messages;
CREATE POLICY "Users can view messages from own tickets"
  ON support_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = support_messages.ticket_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create messages on own tickets" ON support_messages;
CREATE POLICY "Users can create messages on own tickets"
  ON support_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = support_messages.ticket_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can update messages on own tickets" ON support_messages;
CREATE POLICY "Users can update messages on own tickets"
  ON support_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = support_messages.ticket_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Admins can create all messages" ON support_messages;
CREATE POLICY "Admins can create all messages"
  ON support_messages FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update messages" ON support_messages;
CREATE POLICY "Admins can update messages"
  ON support_messages FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- support_attachments
DROP POLICY IF EXISTS "Users can view attachments from own tickets" ON support_attachments;
CREATE POLICY "Users can view attachments from own tickets"
  ON support_attachments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = support_attachments.ticket_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can upload attachments to own tickets" ON support_attachments;
CREATE POLICY "Users can upload attachments to own tickets"
  ON support_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM support_tickets st
      WHERE st.id = support_attachments.ticket_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Admins can manage all attachments" ON support_attachments;
CREATE POLICY "Admins can manage all attachments"
  ON support_attachments FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- support_canned_responses
DROP POLICY IF EXISTS "Admins can view canned responses" ON support_canned_responses;
CREATE POLICY "Admins can view canned responses"
  ON support_canned_responses FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can manage canned responses" ON support_canned_responses;
CREATE POLICY "Admins can manage canned responses"
  ON support_canned_responses FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- kyc_verifications
DROP POLICY IF EXISTS "Users can read own KYC data" ON kyc_verifications;
CREATE POLICY "Users can read own KYC data"
  ON kyc_verifications FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own KYC data" ON kyc_verifications;
CREATE POLICY "Users can insert own KYC data"
  ON kyc_verifications FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own KYC data" ON kyc_verifications;
CREATE POLICY "Users can update own KYC data"
  ON kyc_verifications FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- kyc_documents
DROP POLICY IF EXISTS "Users can update own documents" ON kyc_documents;
CREATE POLICY "Users can update own documents"
  ON kyc_documents FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own documents" ON kyc_documents;
CREATE POLICY "Users can delete own documents"
  ON kyc_documents FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can update all documents" ON kyc_documents;
CREATE POLICY "Admins can update all documents"
  ON kyc_documents FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Users can view own documents or admins can view all" ON kyc_documents;
CREATE POLICY "Users can view own documents or admins can view all"
  ON kyc_documents FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()) OR is_user_admin((select auth.uid())));

-- referral_commissions
DROP POLICY IF EXISTS "Referrers can view their commissions" ON referral_commissions;
CREATE POLICY "Referrers can view their commissions"
  ON referral_commissions FOR SELECT
  TO authenticated
  USING (referrer_id = (select auth.uid()));

-- referral_rebates
DROP POLICY IF EXISTS "Users can view their rebates" ON referral_rebates;
CREATE POLICY "Users can view their rebates"
  ON referral_rebates FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

-- position_modifications
DROP POLICY IF EXISTS "Users can view own position modifications" ON position_modifications;
CREATE POLICY "Users can view own position modifications"
  ON position_modifications FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM futures_positions fp
      WHERE fp.position_id = position_modifications.position_id
      AND fp.user_id = (select auth.uid())
    )
  );

-- liquidation_events
DROP POLICY IF EXISTS "Users can view own liquidation events" ON liquidation_events;
CREATE POLICY "Users can view own liquidation events"
  ON liquidation_events FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

-- liquidation_queue
DROP POLICY IF EXISTS "Users can view own liquidation warnings" ON liquidation_queue;
CREATE POLICY "Users can view own liquidation warnings"
  ON liquidation_queue FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));
