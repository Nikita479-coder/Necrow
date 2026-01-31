/*
  # Fix Admin Sessions - Calculate Online Status Server-Side

  1. Changes
    - Update `get_admin_all_sessions` to calculate `is_online` in the database
    - Uses same logic as `get_platform_breakdown` for consistency
    - Heartbeat must be within last 2 minutes AND is_online must be true

  2. Why
    - Eliminates clock skew between database server and browser
    - Ensures online filter matches the Platform Breakdown count exactly
*/

CREATE OR REPLACE FUNCTION get_admin_all_sessions()
RETURNS TABLE (
  user_id uuid,
  is_online boolean,
  last_activity timestamptz,
  heartbeat timestamptz,
  platform text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    us.user_id,
    (us.is_online AND us.heartbeat > NOW() - INTERVAL '2 minutes') as is_online,
    us.last_activity,
    us.heartbeat,
    COALESCE(us.platform, 'web') as platform
  FROM user_sessions us;
END;
$$;