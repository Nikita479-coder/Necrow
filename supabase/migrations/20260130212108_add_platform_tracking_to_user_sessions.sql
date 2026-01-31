/*
  # Add Platform Tracking to User Sessions

  1. Changes
    - Add `platform` column to track whether user is on app or web
    - Add `device_info` column for additional device details
    - Create function to get platform breakdown stats

  2. Security
    - Existing RLS policies apply
*/

-- Add platform tracking columns
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_sessions' AND column_name = 'platform'
  ) THEN
    ALTER TABLE user_sessions ADD COLUMN platform text DEFAULT 'web';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_sessions' AND column_name = 'device_info'
  ) THEN
    ALTER TABLE user_sessions ADD COLUMN device_info jsonb DEFAULT '{}';
  END IF;
END $$;

-- Create function to get platform breakdown for admin
CREATE OR REPLACE FUNCTION get_platform_breakdown()
RETURNS TABLE (
  platform text,
  total_users bigint,
  online_users bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(us.platform, 'web') as platform,
    COUNT(DISTINCT us.user_id) as total_users,
    COUNT(DISTINCT CASE 
      WHEN us.is_online AND us.heartbeat > NOW() - INTERVAL '2 minutes' 
      THEN us.user_id 
    END) as online_users
  FROM user_sessions us
  GROUP BY us.platform;
END;
$$;

-- Create function to get online users by platform
CREATE OR REPLACE FUNCTION get_online_users_by_platform()
RETURNS TABLE (
  user_id uuid,
  email text,
  username text,
  full_name text,
  platform text,
  device_info jsonb,
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
    us.user_id,
    au.email::text,
    up.username,
    up.full_name,
    COALESCE(us.platform, 'web') as platform,
    COALESCE(us.device_info, '{}') as device_info,
    us.last_activity,
    (us.is_online AND us.heartbeat > NOW() - INTERVAL '2 minutes') as is_online
  FROM user_sessions us
  JOIN auth.users au ON au.id = us.user_id
  LEFT JOIN user_profiles up ON up.id = us.user_id
  WHERE us.heartbeat > NOW() - INTERVAL '24 hours'
  ORDER BY us.last_activity DESC;
END;
$$;