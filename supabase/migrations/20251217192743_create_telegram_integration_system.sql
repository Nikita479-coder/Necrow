/*
  # Telegram Integration System

  ## Overview
  This migration creates the infrastructure for Telegram notifications
  to alert copy trading followers about new trade opportunities.

  ## New Columns on user_profiles
  - `telegram_chat_id` (bigint) - Telegram user's chat ID for sending messages
  - `telegram_linked_at` (timestamptz) - When Telegram account was connected
  - `telegram_username` (text) - Telegram username for display purposes
  - `telegram_blocked` (boolean) - Flag when user has blocked the bot

  ## New Tables

  ### 1. telegram_linking_codes
  One-time codes for secure account linking
  - `id` (uuid, primary key)
  - `user_id` (uuid) - User requesting the link
  - `code` (text, unique) - 8-character alphanumeric code
  - `expires_at` (timestamptz) - Code expiration (10 minutes)
  - `used_at` (timestamptz) - When code was used

  ### 2. telegram_notifications_log
  Comprehensive logging of all Telegram notifications
  - `id` (uuid, primary key)
  - `user_id` (uuid) - Recipient user
  - `pending_trade_id` (uuid) - Associated trade
  - `status` (text) - pending, sent, failed, blocked
  - `error_message` (text) - Error details for failed sends
  - `retry_count` (integer) - Number of retry attempts

  ## Security
  - RLS enabled on all tables
  - Users can only access their own linking codes
  - Admins can view all notification logs
*/

-- Add Telegram columns to user_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'telegram_chat_id'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN telegram_chat_id bigint;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'telegram_linked_at'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN telegram_linked_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'telegram_username'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN telegram_username text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'telegram_blocked'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN telegram_blocked boolean DEFAULT false;
  END IF;
END $$;

-- Create index for Telegram chat ID lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_telegram_chat_id 
  ON user_profiles(telegram_chat_id) 
  WHERE telegram_chat_id IS NOT NULL;

-- Create telegram_linking_codes table
CREATE TABLE IF NOT EXISTS telegram_linking_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  code text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  
  CONSTRAINT code_format CHECK (code ~ '^[A-Z0-9]{8}$')
);

-- Create indexes for telegram_linking_codes
CREATE INDEX IF NOT EXISTS idx_telegram_linking_codes_user 
  ON telegram_linking_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_telegram_linking_codes_code 
  ON telegram_linking_codes(code) 
  WHERE used_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_telegram_linking_codes_expires 
  ON telegram_linking_codes(expires_at) 
  WHERE used_at IS NULL;

-- Create telegram_notifications_log table
CREATE TABLE IF NOT EXISTS telegram_notifications_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  pending_trade_id uuid REFERENCES pending_copy_trades(id) ON DELETE SET NULL,
  
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'blocked')),
  error_message text,
  retry_count integer DEFAULT 0,
  
  created_at timestamptz DEFAULT now() NOT NULL,
  sent_at timestamptz,
  
  CONSTRAINT max_retries CHECK (retry_count >= 0 AND retry_count <= 5)
);

-- Create indexes for telegram_notifications_log
CREATE INDEX IF NOT EXISTS idx_telegram_notifications_user 
  ON telegram_notifications_log(user_id);
CREATE INDEX IF NOT EXISTS idx_telegram_notifications_trade 
  ON telegram_notifications_log(pending_trade_id);
CREATE INDEX IF NOT EXISTS idx_telegram_notifications_status 
  ON telegram_notifications_log(status);
CREATE INDEX IF NOT EXISTS idx_telegram_notifications_created 
  ON telegram_notifications_log(created_at DESC);

-- Enable RLS
ALTER TABLE telegram_linking_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE telegram_notifications_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for telegram_linking_codes

-- Users can view their own linking codes
CREATE POLICY "Users can view own linking codes"
  ON telegram_linking_codes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Users can insert their own linking codes (via function)
CREATE POLICY "Users can create own linking codes"
  ON telegram_linking_codes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can update their own linking codes
CREATE POLICY "Users can update own linking codes"
  ON telegram_linking_codes FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Users can delete their own linking codes
CREATE POLICY "Users can delete own linking codes"
  ON telegram_linking_codes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- RLS Policies for telegram_notifications_log

-- Users can view their own notification history
CREATE POLICY "Users can view own telegram notifications"
  ON telegram_notifications_log FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- System can insert notifications (service role)
CREATE POLICY "Service role can insert telegram notifications"
  ON telegram_notifications_log FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- System can update notifications (service role)
CREATE POLICY "Service role can update telegram notifications"
  ON telegram_notifications_log FOR UPDATE
  TO authenticated
  USING (true);

-- Admins can view all telegram notifications
CREATE POLICY "Admins can view all telegram notifications"
  ON telegram_notifications_log FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid() AND up.is_admin = true
    )
    OR
    (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean = true
  );

-- Function to generate a telegram linking code
CREATE OR REPLACE FUNCTION generate_telegram_linking_code(p_user_id uuid)
RETURNS TABLE(code text, expires_at timestamptz, bot_username text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_expires_at timestamptz;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_recent_count integer;
BEGIN
  -- Check rate limit: max 5 codes per hour
  SELECT COUNT(*) INTO v_recent_count
  FROM telegram_linking_codes
  WHERE user_id = p_user_id
  AND created_at > now() - interval '1 hour';
  
  IF v_recent_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit exceeded. Please try again later.';
  END IF;

  -- Delete any existing unused codes for this user
  DELETE FROM telegram_linking_codes
  WHERE user_id = p_user_id
  AND used_at IS NULL;
  
  -- Generate unique 8-character code
  LOOP
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::integer, 1);
    END LOOP;
    
    -- Check if code already exists
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM telegram_linking_codes WHERE telegram_linking_codes.code = v_code
    );
  END LOOP;
  
  -- Set expiration to 10 minutes from now
  v_expires_at := now() + interval '10 minutes';
  
  -- Insert the new code
  INSERT INTO telegram_linking_codes (user_id, code, expires_at)
  VALUES (p_user_id, v_code, v_expires_at);
  
  -- Return the code and expiration
  RETURN QUERY SELECT v_code, v_expires_at, 'YourBotUsername'::text;
END;
$$;

-- Function to verify and use a telegram linking code
CREATE OR REPLACE FUNCTION verify_telegram_linking_code(
  p_code text,
  p_chat_id bigint,
  p_username text DEFAULT NULL
)
RETURNS TABLE(success boolean, user_id uuid, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_record record;
BEGIN
  -- Find the code
  SELECT tlc.*, up.telegram_chat_id as existing_chat_id
  INTO v_code_record
  FROM telegram_linking_codes tlc
  JOIN user_profiles up ON up.id = tlc.user_id
  WHERE tlc.code = upper(p_code)
  AND tlc.used_at IS NULL
  AND tlc.expires_at > now();
  
  IF v_code_record IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Invalid or expired code'::text;
    RETURN;
  END IF;
  
  -- Check if this chat_id is already linked to another account
  IF EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE telegram_chat_id = p_chat_id 
    AND id != v_code_record.user_id
  ) THEN
    RETURN QUERY SELECT false, NULL::uuid, 'This Telegram account is already linked to another user'::text;
    RETURN;
  END IF;
  
  -- Mark code as used
  UPDATE telegram_linking_codes
  SET used_at = now()
  WHERE id = v_code_record.id;
  
  -- Update user profile with Telegram info
  UPDATE user_profiles
  SET 
    telegram_chat_id = p_chat_id,
    telegram_username = p_username,
    telegram_linked_at = now(),
    telegram_blocked = false
  WHERE id = v_code_record.user_id;
  
  RETURN QUERY SELECT true, v_code_record.user_id, 'Account linked successfully!'::text;
END;
$$;

-- Function to unlink telegram account
CREATE OR REPLACE FUNCTION unlink_telegram_account(p_chat_id bigint)
RETURNS TABLE(success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Find the user with this chat_id
  SELECT id INTO v_user_id
  FROM user_profiles
  WHERE telegram_chat_id = p_chat_id;
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'No account linked to this Telegram'::text;
    RETURN;
  END IF;
  
  -- Clear telegram info
  UPDATE user_profiles
  SET 
    telegram_chat_id = NULL,
    telegram_username = NULL,
    telegram_linked_at = NULL,
    telegram_blocked = false
  WHERE id = v_user_id;
  
  RETURN QUERY SELECT true, 'Account unlinked successfully'::text;
END;
$$;

-- Function to mark user as having blocked the bot
CREATE OR REPLACE FUNCTION mark_telegram_blocked(p_chat_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE user_profiles
  SET telegram_blocked = true
  WHERE telegram_chat_id = p_chat_id;
END;
$$;

-- Function to get followers with Telegram enabled for a trader
CREATE OR REPLACE FUNCTION get_telegram_followers_for_trader(p_trader_id uuid)
RETURNS TABLE(
  user_id uuid,
  telegram_chat_id bigint,
  copy_relationship_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cr.follower_id as user_id,
    up.telegram_chat_id,
    cr.id as copy_relationship_id
  FROM copy_relationships cr
  JOIN user_profiles up ON up.id = cr.follower_id
  WHERE cr.trader_id = p_trader_id
  AND cr.status = 'active'
  AND cr.is_active = true
  AND up.telegram_chat_id IS NOT NULL
  AND up.telegram_blocked = false;
END;
$$;

-- Function to log telegram notification
CREATE OR REPLACE FUNCTION log_telegram_notification(
  p_user_id uuid,
  p_pending_trade_id uuid,
  p_status text,
  p_error_message text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO telegram_notifications_log (
    user_id, 
    pending_trade_id, 
    status, 
    error_message,
    sent_at
  )
  VALUES (
    p_user_id,
    p_pending_trade_id,
    p_status,
    p_error_message,
    CASE WHEN p_status = 'sent' THEN now() ELSE NULL END
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- Function to update telegram notification status
CREATE OR REPLACE FUNCTION update_telegram_notification(
  p_log_id uuid,
  p_status text,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE telegram_notifications_log
  SET 
    status = p_status,
    error_message = COALESCE(p_error_message, error_message),
    sent_at = CASE WHEN p_status = 'sent' THEN now() ELSE sent_at END,
    retry_count = CASE WHEN p_status = 'failed' THEN retry_count + 1 ELSE retry_count END
  WHERE id = p_log_id;
END;
$$;

-- Function to get notification stats for a pending trade
CREATE OR REPLACE FUNCTION get_telegram_notification_stats(p_pending_trade_id uuid)
RETURNS TABLE(
  total_sent integer,
  total_failed integer,
  total_blocked integer,
  total_pending integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE status = 'sent')::integer as total_sent,
    COUNT(*) FILTER (WHERE status = 'failed')::integer as total_failed,
    COUNT(*) FILTER (WHERE status = 'blocked')::integer as total_blocked,
    COUNT(*) FILTER (WHERE status = 'pending')::integer as total_pending
  FROM telegram_notifications_log
  WHERE pending_trade_id = p_pending_trade_id;
END;
$$;

-- Function to get detailed notification log for admin
CREATE OR REPLACE FUNCTION get_telegram_notification_details(p_pending_trade_id uuid)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  username text,
  telegram_username text,
  status text,
  error_message text,
  retry_count integer,
  created_at timestamptz,
  sent_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tnl.id,
    tnl.user_id,
    up.username,
    up.telegram_username,
    tnl.status,
    tnl.error_message,
    tnl.retry_count,
    tnl.created_at,
    tnl.sent_at
  FROM telegram_notifications_log tnl
  JOIN user_profiles up ON up.id = tnl.user_id
  WHERE tnl.pending_trade_id = p_pending_trade_id
  ORDER BY tnl.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_telegram_linking_code(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_telegram_linking_code(text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION unlink_telegram_account(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_telegram_blocked(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION get_telegram_followers_for_trader(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_telegram_notification(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_telegram_notification(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_telegram_notification_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_telegram_notification_details(uuid) TO authenticated;
