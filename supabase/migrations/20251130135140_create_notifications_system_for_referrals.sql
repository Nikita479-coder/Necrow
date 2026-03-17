/*
  # Create Notifications System for Referral Payouts

  ## Summary
  Creates a notifications table and system to notify users when they receive
  referral commission payouts from their referees' trading fees.

  ## New Tables
  1. `notifications`
     - `id` (uuid, primary key)
     - `user_id` (uuid, references auth.users) - who receives the notification
     - `type` (text) - notification type (referral_payout, trade_executed, etc.)
     - `title` (text) - notification title
     - `message` (text) - notification message
     - `data` (jsonb) - additional data (amount, currency, referee info, etc.)
     - `read` (boolean) - whether user has read it
     - `created_at` (timestamptz)

  ## Changes
  1. Create notifications table with RLS
  2. Create helper function to send notifications
  3. Users can only view their own notifications
  4. Users can mark their own notifications as read

  ## Security
  - RLS enabled on notifications table
  - Users can only access their own notifications
  - Notification sending is SECURITY DEFINER to allow system to send
*/

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type text NOT NULL CHECK (type IN ('referral_payout', 'trade_executed', 'kyc_update', 'account_update', 'system')),
  title text NOT NULL,
  message text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb,
  read boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policies for notifications
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(user_id, created_at DESC);

-- Helper function to send notification
CREATE OR REPLACE FUNCTION send_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (p_user_id, p_type, p_title, p_message, p_data)
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;