/*
  # Optimize RLS Policies - Part 3 (User & Support Tables)

  ## Description
  Continues optimizing RLS policies with auth.uid() wrapper.
*/

-- user_vip_status
DROP POLICY IF EXISTS "Users can read own VIP status" ON user_vip_status;
CREATE POLICY "Users can read own VIP status" ON user_vip_status
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_bonuses
DROP POLICY IF EXISTS "Users can read own bonuses" ON user_bonuses;
CREATE POLICY "Users can read own bonuses" ON user_bonuses
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- support_tickets
DROP POLICY IF EXISTS "Users can read own tickets" ON support_tickets;
CREATE POLICY "Users can read own tickets" ON support_tickets
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can create tickets" ON support_tickets;
CREATE POLICY "Users can create tickets" ON support_tickets
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own tickets" ON support_tickets;
CREATE POLICY "Users can update own tickets" ON support_tickets
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- support_messages
DROP POLICY IF EXISTS "Users can read messages for own tickets" ON support_messages;
CREATE POLICY "Users can read messages for own tickets" ON support_messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM support_tickets 
    WHERE support_tickets.id = support_messages.ticket_id 
    AND support_tickets.user_id = (select auth.uid())
  ));

DROP POLICY IF EXISTS "Users can insert messages for own tickets" ON support_messages;
CREATE POLICY "Users can insert messages for own tickets" ON support_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = (select auth.uid()) AND
    EXISTS (
      SELECT 1 FROM support_tickets 
      WHERE support_tickets.id = support_messages.ticket_id 
      AND support_tickets.user_id = (select auth.uid())
    )
  );

-- whitelisted_wallets
DROP POLICY IF EXISTS "Users can read own whitelisted wallets" ON whitelisted_wallets;
CREATE POLICY "Users can read own whitelisted wallets" ON whitelisted_wallets
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own whitelisted wallets" ON whitelisted_wallets;
CREATE POLICY "Users can insert own whitelisted wallets" ON whitelisted_wallets
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own whitelisted wallets" ON whitelisted_wallets;
CREATE POLICY "Users can update own whitelisted wallets" ON whitelisted_wallets
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own whitelisted wallets" ON whitelisted_wallets;
CREATE POLICY "Users can delete own whitelisted wallets" ON whitelisted_wallets
  FOR DELETE TO authenticated USING (user_id = (select auth.uid()));

-- shark_cards
DROP POLICY IF EXISTS "Users can read own shark cards" ON shark_cards;
CREATE POLICY "Users can read own shark cards" ON shark_cards
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- shark_card_applications
DROP POLICY IF EXISTS "Users can read own applications" ON shark_card_applications;
CREATE POLICY "Users can read own applications" ON shark_card_applications
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own applications" ON shark_card_applications;
CREATE POLICY "Users can insert own applications" ON shark_card_applications
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- shark_card_transactions
DROP POLICY IF EXISTS "Users can read own card transactions" ON shark_card_transactions;
CREATE POLICY "Users can read own card transactions" ON shark_card_transactions
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- copy_trade_allocations (has follower_id directly)
DROP POLICY IF EXISTS "Users can read own allocations" ON copy_trade_allocations;
CREATE POLICY "Users can read own allocations" ON copy_trade_allocations
  FOR SELECT TO authenticated USING (follower_id = (select auth.uid()));

-- vip_daily_snapshots
DROP POLICY IF EXISTS "Users can read own VIP snapshots" ON vip_daily_snapshots;
CREATE POLICY "Users can read own VIP snapshots" ON vip_daily_snapshots
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_terms_acceptance
DROP POLICY IF EXISTS "Users can read own terms acceptance" ON user_terms_acceptance;
CREATE POLICY "Users can read own terms acceptance" ON user_terms_acceptance
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own terms acceptance" ON user_terms_acceptance;
CREATE POLICY "Users can insert own terms acceptance" ON user_terms_acceptance
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- user_trusted_ips
DROP POLICY IF EXISTS "Users can read own trusted IPs" ON user_trusted_ips;
CREATE POLICY "Users can read own trusted IPs" ON user_trusted_ips
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own trusted IPs" ON user_trusted_ips;
CREATE POLICY "Users can insert own trusted IPs" ON user_trusted_ips
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own trusted IPs" ON user_trusted_ips;
CREATE POLICY "Users can delete own trusted IPs" ON user_trusted_ips
  FOR DELETE TO authenticated USING (user_id = (select auth.uid()));

-- user_activity_log
DROP POLICY IF EXISTS "Users can read own activity logs" ON user_activity_log;
CREATE POLICY "Users can read own activity logs" ON user_activity_log
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_stakes
DROP POLICY IF EXISTS "Users can read own stakes" ON user_stakes;
CREATE POLICY "Users can read own stakes" ON user_stakes
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert stakes" ON user_stakes;
CREATE POLICY "Users can insert stakes" ON user_stakes
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- locked_bonuses
DROP POLICY IF EXISTS "Users can read own locked bonuses" ON locked_bonuses;
CREATE POLICY "Users can read own locked bonuses" ON locked_bonuses
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_notes (if users can see their own notes)
DROP POLICY IF EXISTS "Users can read own notes" ON user_notes;
CREATE POLICY "Users can read own notes" ON user_notes
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_sessions
DROP POLICY IF EXISTS "Users can read own sessions" ON user_sessions;
CREATE POLICY "Users can read own sessions" ON user_sessions
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));
