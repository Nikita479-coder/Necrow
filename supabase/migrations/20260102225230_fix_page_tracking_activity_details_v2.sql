/*
  # Fix Page Tracking Activity Details Display
  
  Updates the get_user_recent_activity function to return activity_details
  as a JSON object so the UI can properly display page information.
*/

-- Drop and recreate the function with correct return type
DROP FUNCTION IF EXISTS get_user_recent_activity(uuid, integer, integer);

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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_recent_activity TO authenticated;