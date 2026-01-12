/*
  # Create Page Visit Tracking System

  Enhances the existing user_activity_log to track detailed page visits
  and provides functions to view user browsing patterns.

  1. New Functions
    - `track_page_visit` - Log page visits with duration
    - `get_user_recent_activity` - Get detailed activity log for a specific user
    - `get_active_user_sessions` - Get currently active users with their current page
*/

-- Function to track page visits
CREATE OR REPLACE FUNCTION track_page_visit(
  p_user_id uuid,
  p_page_path text,
  p_page_title text DEFAULT NULL,
  p_duration_seconds integer DEFAULT NULL,
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
  -- Log the page visit
  INSERT INTO user_activity_log (
    user_id,
    activity_type,
    activity_details,
    ip_address
  ) VALUES (
    p_user_id,
    'page_visit',
    jsonb_build_object(
      'page_path', p_page_path,
      'page_title', p_page_title,
      'duration_seconds', p_duration_seconds,
      'timestamp', now()
    ),
    p_ip_address
  )
  RETURNING id INTO v_activity_id;

  -- Update user session
  PERFORM update_user_session(p_user_id, true, p_ip_address, NULL);

  RETURN v_activity_id;
END;
$$;

-- Function to get recent activity for a specific user
CREATE OR REPLACE FUNCTION get_user_recent_activity(
  p_user_id uuid,
  p_hours integer DEFAULT 24,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  activity_type text,
  activity_details jsonb,
  ip_address text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    ual.id,
    ual.activity_type,
    ual.activity_details,
    ual.ip_address,
    ual.created_at
  FROM user_activity_log ual
  WHERE ual.user_id = p_user_id
    AND ual.created_at > now() - (p_hours || ' hours')::interval
  ORDER BY ual.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Function to get active user sessions with current page
CREATE OR REPLACE FUNCTION get_active_user_sessions(
  p_minutes integer DEFAULT 30
)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  current_page text,
  last_activity timestamptz,
  total_page_views bigint,
  session_duration text,
  ip_address text,
  is_online boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  WITH latest_page_visit AS (
    SELECT DISTINCT ON (user_id)
      user_id,
      activity_details->>'page_path' as page_path,
      created_at
    FROM user_activity_log
    WHERE activity_type = 'page_visit'
      AND created_at > now() - (p_minutes || ' minutes')::interval
    ORDER BY user_id, created_at DESC
  ),
  page_view_counts AS (
    SELECT
      user_id,
      COUNT(*) as view_count,
      MIN(created_at) as first_visit,
      MAX(created_at) as last_visit
    FROM user_activity_log
    WHERE activity_type = 'page_visit'
      AND created_at > now() - (p_minutes || ' minutes')::interval
    GROUP BY user_id
  )
  SELECT
    us.user_id,
    au.email::text,
    up.full_name,
    up.username,
    lpv.page_path as current_page,
    us.last_activity,
    COALESCE(pvc.view_count, 0) as total_page_views,
    CASE
      WHEN EXTRACT(EPOCH FROM (now() - pvc.first_visit)) < 60 THEN 
        ROUND(EXTRACT(EPOCH FROM (now() - pvc.first_visit)))::text || 's'
      WHEN EXTRACT(EPOCH FROM (now() - pvc.first_visit)) < 3600 THEN 
        ROUND(EXTRACT(EPOCH FROM (now() - pvc.first_visit)) / 60)::text || 'm'
      ELSE 
        ROUND(EXTRACT(EPOCH FROM (now() - pvc.first_visit)) / 3600, 1)::text || 'h'
    END as session_duration,
    us.ip_address,
    us.is_online
  FROM user_sessions us
  INNER JOIN auth.users au ON au.id = us.user_id
  LEFT JOIN user_profiles up ON up.id = us.user_id
  LEFT JOIN latest_page_visit lpv ON lpv.user_id = us.user_id
  LEFT JOIN page_view_counts pvc ON pvc.user_id = us.user_id
  WHERE us.last_activity > now() - (p_minutes || ' minutes')::interval
    AND us.is_online = true
  ORDER BY us.last_activity DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION track_page_visit TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_recent_activity TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_user_sessions TO authenticated;