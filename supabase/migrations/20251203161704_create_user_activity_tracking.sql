/*
  # Create User Activity Tracking System

  1. New Tables
    - `user_sessions` - Track online/offline status with last activity timestamp
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `is_online` (boolean)
      - `last_activity` (timestamptz)
      - `last_seen` (timestamptz)
      - `ip_address` (text)
      - `user_agent` (text)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `user_activity_log` - Comprehensive activity logging
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key)
      - `activity_type` (text) - login, logout, trade, deposit, withdraw, etc.
      - `activity_details` (jsonb) - flexible data storage
      - `ip_address` (text)
      - `created_at` (timestamptz)

  2. Functions
    - `update_user_session` - Update or create user session
    - `get_online_users` - Get list of currently online users
    - `log_user_activity` - Log user activities

  3. Security
    - Enable RLS on all tables
    - Admins can view all sessions and activities
    - Users can only update their own session
*/

-- Create user_sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  is_online boolean DEFAULT true,
  last_activity timestamptz DEFAULT now(),
  last_seen timestamptz DEFAULT now(),
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Create user_activity_log table
CREATE TABLE IF NOT EXISTS user_activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  activity_type text NOT NULL,
  activity_details jsonb DEFAULT '{}'::jsonb,
  ip_address text,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_online ON user_sessions(is_online);
CREATE INDEX IF NOT EXISTS idx_user_sessions_last_activity ON user_sessions(last_activity);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_user_id ON user_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_type ON user_activity_log(activity_type);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_created ON user_activity_log(created_at DESC);

-- Enable RLS
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_sessions
CREATE POLICY "Users can view own session"
  ON user_sessions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own session"
  ON user_sessions FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own session"
  ON user_sessions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all sessions"
  ON user_sessions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- RLS Policies for user_activity_log
CREATE POLICY "Users can view own activity"
  ON user_activity_log FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity"
  ON user_activity_log FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all activity"
  ON user_activity_log FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Function to update user session
CREATE OR REPLACE FUNCTION update_user_session(
  p_user_id uuid,
  p_is_online boolean DEFAULT true,
  p_ip_address text DEFAULT NULL,
  p_user_agent text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_sessions (user_id, is_online, last_activity, last_seen, ip_address, user_agent)
  VALUES (p_user_id, p_is_online, now(), now(), p_ip_address, p_user_agent)
  ON CONFLICT (user_id) DO UPDATE
  SET
    is_online = p_is_online,
    last_activity = now(),
    last_seen = CASE WHEN p_is_online THEN now() ELSE user_sessions.last_seen END,
    ip_address = COALESCE(p_ip_address, user_sessions.ip_address),
    user_agent = COALESCE(p_user_agent, user_sessions.user_agent),
    updated_at = now();
END;
$$;

-- Function to get online users
CREATE OR REPLACE FUNCTION get_online_users()
RETURNS TABLE (
  user_id uuid,
  username text,
  email text,
  last_activity timestamptz,
  is_online boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.user_id,
    p.username,
    u.email,
    s.last_activity,
    s.is_online
  FROM user_sessions s
  INNER JOIN auth.users u ON u.id = s.user_id
  LEFT JOIN user_profiles p ON p.id = s.user_id
  WHERE s.is_online = true
    AND s.last_activity > now() - interval '15 minutes'
  ORDER BY s.last_activity DESC;
END;
$$;

-- Function to log user activity
CREATE OR REPLACE FUNCTION log_user_activity(
  p_user_id uuid,
  p_activity_type text,
  p_activity_details jsonb DEFAULT '{}'::jsonb,
  p_ip_address text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_activity_id uuid;
BEGIN
  INSERT INTO user_activity_log (user_id, activity_type, activity_details, ip_address)
  VALUES (p_user_id, p_activity_type, p_activity_details, p_ip_address)
  RETURNING id INTO v_activity_id;

  RETURN v_activity_id;
END;
$$;

-- Auto-mark users as offline after 15 minutes of inactivity
CREATE OR REPLACE FUNCTION mark_inactive_users_offline()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE user_sessions
  SET is_online = false
  WHERE is_online = true
    AND last_activity < now() - interval '15 minutes';
END;
$$;