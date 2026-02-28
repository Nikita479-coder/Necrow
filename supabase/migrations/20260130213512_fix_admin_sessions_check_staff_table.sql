/*
  # Fix Admin Sessions - Check Staff Table

  1. Problem
    - `get_admin_all_sessions` only checks JWT metadata for admin status
    - Staff members without `is_admin` in JWT would get empty results
    - This caused online filter to show fewer users than expected

  2. Solution
    - Check both JWT metadata AND admin_staff table
    - Match the same pattern used by other admin functions like get_admin_users_list
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
DECLARE
  v_is_admin boolean;
BEGIN
  v_is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);

  IF NOT v_is_admin THEN
    v_is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND is_active = true
    );
  END IF;

  IF NOT v_is_admin THEN
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