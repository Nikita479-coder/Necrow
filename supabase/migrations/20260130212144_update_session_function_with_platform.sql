/*
  # Update User Session Function with Platform Tracking

  1. Changes
    - Add platform and device_info parameters to update_user_session
    - Function now stores what platform (app/web) user is accessing from
*/

-- Drop existing function and recreate with platform support
DROP FUNCTION IF EXISTS update_user_session(uuid, boolean, text, text);
DROP FUNCTION IF EXISTS update_user_session(uuid, boolean);

CREATE OR REPLACE FUNCTION update_user_session(
  p_user_id uuid,
  p_is_online boolean,
  p_ip_address text DEFAULT NULL,
  p_user_agent text DEFAULT NULL,
  p_platform text DEFAULT 'web',
  p_device_info jsonb DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_sessions (
    user_id, 
    is_online, 
    last_activity, 
    last_seen, 
    heartbeat, 
    ip_address, 
    user_agent,
    platform,
    device_info
  )
  VALUES (
    p_user_id, 
    p_is_online, 
    now(), 
    now(), 
    now(), 
    p_ip_address, 
    p_user_agent,
    COALESCE(p_platform, 'web'),
    COALESCE(p_device_info, '{}')
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    is_online = p_is_online,
    last_activity = now(),
    heartbeat = now(),
    last_seen = CASE WHEN p_is_online THEN now() ELSE user_sessions.last_seen END,
    ip_address = COALESCE(p_ip_address, user_sessions.ip_address),
    user_agent = COALESCE(p_user_agent, user_sessions.user_agent),
    platform = COALESCE(p_platform, user_sessions.platform, 'web'),
    device_info = CASE 
      WHEN p_device_info IS NOT NULL AND p_device_info != '{}' 
      THEN p_device_info 
      ELSE user_sessions.device_info 
    END,
    updated_at = now();
END;
$$;