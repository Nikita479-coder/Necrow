/*
  # Fix get_online_users function type mismatch
  
  1. Problem
    - Function returns varchar(255) for email but expects text
    - Causes query execution error
  
  2. Solution
    - Drop and recreate function with correct types
    - Cast email to text explicitly
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_online_users();

-- Recreate with correct types
CREATE OR REPLACE FUNCTION get_online_users()
RETURNS TABLE(
  user_id uuid,
  username text,
  email text,
  last_activity timestamptz,
  is_online boolean,
  heartbeat timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.user_id,
    p.username::text,
    u.email::text,
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
