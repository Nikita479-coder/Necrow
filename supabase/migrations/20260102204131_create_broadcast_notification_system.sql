/*
  # Create Broadcast Notification System

  1. Purpose
    - Allow admins to send notifications to ALL users at once from the CRM
    - Support for promotional messages like referral bonus reminders
    - Track broadcast history for audit purposes

  2. New Tables
    - `broadcast_notification_logs` - Track all broadcast notifications sent
      - `id` (uuid, primary key)
      - `admin_id` (uuid) - Who sent the broadcast
      - `title` (text) - Notification title
      - `message` (text) - Notification message
      - `notification_type` (text) - Type of notification
      - `redirect_url` (text) - Where to redirect when clicked
      - `user_count` (integer) - Number of users notified
      - `created_at` (timestamptz) - When it was sent

  3. New Functions
    - `broadcast_notification_to_all_users` - Send notification to all users

  4. Security
    - Only admins can execute the broadcast function
    - Logs are readable by admins only
*/

-- Create broadcast notification logs table
CREATE TABLE IF NOT EXISTS broadcast_notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES user_profiles(id),
  title text NOT NULL,
  message text NOT NULL,
  notification_type text NOT NULL DEFAULT 'system',
  redirect_url text,
  user_count integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_broadcast_logs_admin ON broadcast_notification_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_broadcast_logs_created ON broadcast_notification_logs(created_at DESC);

-- Enable RLS
ALTER TABLE broadcast_notification_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view broadcast logs
CREATE POLICY "Admins can view broadcast logs"
  ON broadcast_notification_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Create the broadcast notification function
CREATE OR REPLACE FUNCTION broadcast_notification_to_all_users(
  p_admin_id uuid,
  p_title text,
  p_message text,
  p_notification_type text DEFAULT 'reward',
  p_redirect_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_count integer;
  v_log_id uuid;
  v_is_admin boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = p_admin_id;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Validate inputs
  IF p_title IS NULL OR p_title = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Title is required'
    );
  END IF;

  IF p_message IS NULL OR p_message = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Message is required'
    );
  END IF;

  -- Insert notifications for all users
  INSERT INTO notifications (user_id, type, title, message, read, data, redirect_url)
  SELECT 
    up.id,
    p_notification_type,
    p_title,
    p_message,
    false,
    jsonb_build_object('broadcast', true, 'sent_by', p_admin_id),
    p_redirect_url
  FROM user_profiles up;

  GET DIAGNOSTICS v_user_count = ROW_COUNT;

  -- Log the broadcast
  INSERT INTO broadcast_notification_logs (admin_id, title, message, notification_type, redirect_url, user_count)
  VALUES (p_admin_id, p_title, p_message, p_notification_type, p_redirect_url, v_user_count)
  RETURNING id INTO v_log_id;

  -- Also log to admin activity
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, details)
  VALUES (
    p_admin_id,
    'broadcast_notification',
    format('Sent broadcast notification to %s users: %s', v_user_count, p_title),
    NULL,
    jsonb_build_object(
      'title', p_title,
      'message', p_message,
      'notification_type', p_notification_type,
      'redirect_url', p_redirect_url,
      'user_count', v_user_count,
      'log_id', v_log_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_count', v_user_count,
    'log_id', v_log_id,
    'message', format('Successfully sent notification to %s users', v_user_count)
  );
END;
$$;

-- Grant execute permission to authenticated users (function checks admin internally)
GRANT EXECUTE ON FUNCTION broadcast_notification_to_all_users TO authenticated;

-- Create function to get broadcast history
CREATE OR REPLACE FUNCTION get_broadcast_history(
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  admin_id uuid,
  admin_name text,
  title text,
  message text,
  notification_type text,
  redirect_url text,
  user_count integer,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.is_admin = true
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    bl.id,
    bl.admin_id,
    up.full_name as admin_name,
    bl.title,
    bl.message,
    bl.notification_type,
    bl.redirect_url,
    bl.user_count,
    bl.created_at
  FROM broadcast_notification_logs bl
  LEFT JOIN user_profiles up ON bl.admin_id = up.id
  ORDER BY bl.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_broadcast_history TO authenticated;
