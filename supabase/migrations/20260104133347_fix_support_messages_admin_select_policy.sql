/*
  # Fix Support Messages Admin Policies

  ## Issue
  The admin SELECT policy for support_messages was removed during 
  RLS optimization but not replaced, causing admins to fail when 
  sending messages to tickets.

  ## Changes
  1. Add admin SELECT policy for support_messages
  2. Fix support_attachments policy (references wrong column)
*/

-- Add admin SELECT policy for support_messages
DROP POLICY IF EXISTS "Admins can view all messages" ON support_messages;
CREATE POLICY "Admins can view all messages"
  ON support_messages FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- Fix support_attachments policies - ticket_id doesn't exist, need to join through message_id
DROP POLICY IF EXISTS "Users can view attachments from own tickets" ON support_attachments;
CREATE POLICY "Users can view attachments from own tickets"
  ON support_attachments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM support_messages sm
      JOIN support_tickets st ON st.id = sm.ticket_id
      WHERE sm.id = support_attachments.message_id
      AND st.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can upload attachments to own tickets" ON support_attachments;
CREATE POLICY "Users can upload attachments to own tickets"
  ON support_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM support_messages sm
      JOIN support_tickets st ON st.id = sm.ticket_id
      WHERE sm.id = support_attachments.message_id
      AND st.user_id = (select auth.uid())
    )
  );
