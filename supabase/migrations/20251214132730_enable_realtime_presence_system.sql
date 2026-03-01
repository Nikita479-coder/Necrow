/*
  # Enable Real-Time Presence System
  
  1. Changes
    - Enable realtime on user_sessions table
    - Add publication for realtime updates
    - Optimize indexes for realtime queries
    - Add heartbeat column for better presence detection
    - Create function to get user presence status

  2. Security
    - Maintain existing RLS policies
    - Allow authenticated users to see online status of other users
*/

-- Enable realtime on user_sessions table
ALTER PUBLICATION supabase_realtime ADD TABLE user_sessions;

-- Add heartbeat timestamp for more accurate presence
ALTER TABLE user_sessions
ADD COLUMN IF NOT EXISTS heartbeat timestamptz DEFAULT now();

-- Create index for heartbeat queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_heartbeat ON user_sessions(heartbeat DESC);

-- Drop the old update function and recreate with heartbeat
DROP FUNCTION IF EXISTS update_user_session(uuid, boolean, text, text);

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
  INSERT INTO user_sessions (user_id, is_online, last_activity, last_seen, heartbeat, ip_address, user_agent)
  VALUES (p_user_id, p_is_online, now(), now(), now(), p_ip_address, p_user_agent)
  ON CONFLICT (user_id) DO UPDATE
  SET
    is_online = p_is_online,
    last_activity = now(),
    heartbeat = now(),
    last_seen = CASE WHEN p_is_online THEN now() ELSE user_sessions.last_seen END,
    ip_address = COALESCE(p_ip_address, user_sessions.ip_address),
    user_agent = COALESCE(p_user_agent, user_sessions.user_agent),
    updated_at = now();
END;
$$;

-- Update get_online_users to use heartbeat
DROP FUNCTION IF EXISTS get_online_users();

CREATE OR REPLACE FUNCTION get_online_users()
RETURNS TABLE (
  user_id uuid,
  username text,
  email text,
  last_activity timestamptz,
  is_online boolean,
  heartbeat timestamptz
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
    s.is_online,
    s.heartbeat
  FROM user_sessions s
  INNER JOIN auth.users u ON u.id = s.user_id
  LEFT JOIN user_profiles p ON p.id = s.user_id
  WHERE s.is_online = true
    AND s.heartbeat > now() - interval '2 minutes'
  ORDER BY s.heartbeat DESC;
END;
$$;

-- Function to check if specific user is online
CREATE OR REPLACE FUNCTION is_user_online(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_online boolean;
BEGIN
  SELECT 
    CASE 
      WHEN s.is_online = true 
        AND s.heartbeat > now() - interval '2 minutes'
      THEN true
      ELSE false
    END INTO v_is_online
  FROM user_sessions s
  WHERE s.user_id = p_user_id;

  RETURN COALESCE(v_is_online, false);
END;
$$;

-- Function to get multiple users' online status
CREATE OR REPLACE FUNCTION get_users_online_status(p_user_ids uuid[])
RETURNS TABLE (
  user_id uuid,
  is_online boolean,
  last_seen timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.user_id,
    CASE 
      WHEN s.is_online = true 
        AND s.heartbeat > now() - interval '2 minutes'
      THEN true
      ELSE false
    END as is_online,
    s.last_seen
  FROM user_sessions s
  WHERE s.user_id = ANY(p_user_ids);
END;
$$;

-- Update mark_inactive_users_offline to use heartbeat
DROP FUNCTION IF EXISTS mark_inactive_users_offline();

CREATE OR REPLACE FUNCTION mark_inactive_users_offline()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE user_sessions
  SET 
    is_online = false,
    updated_at = now()
  WHERE is_online = true
    AND heartbeat < now() - interval '2 minutes';
END;
$$;

-- Drop old policy if exists and create new one
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Authenticated users can view online status" ON user_sessions;
  
  CREATE POLICY "Authenticated users can view online status"
    ON user_sessions FOR SELECT
    TO authenticated
    USING (true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
