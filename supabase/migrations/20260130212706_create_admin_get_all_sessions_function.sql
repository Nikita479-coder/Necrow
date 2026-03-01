/*
  # Create Admin Get All Sessions Function

  1. New Function
    - `get_admin_all_sessions` - Returns all user sessions for admin dashboard
    - Bypasses RLS to ensure admins can see all sessions
    - Used for the online status tracking in admin panel

  2. Security
    - Only accessible by admin users
    - Returns session data needed for online status display
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
    us.is_online,
    us.last_activity,
    us.heartbeat,
    COALESCE(us.platform, 'web') as platform
  FROM user_sessions us;
END;
$$;