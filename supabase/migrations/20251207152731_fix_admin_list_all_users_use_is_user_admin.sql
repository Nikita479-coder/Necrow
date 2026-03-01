/*
  # Fix admin_list_all_users to use is_user_admin helper
  
  1. Changes
    - Update admin_list_all_users to use the is_user_admin() helper function
    - This checks raw_app_meta_data->>'is_admin' like other admin functions
    - Consistent with existing admin check pattern
*/

CREATE OR REPLACE FUNCTION admin_list_all_users(
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  email text,
  username text,
  full_name text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is admin using the helper function
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    au.id as user_id,
    au.email::text,
    COALESCE(up.username, au.email)::text as username,
    COALESCE(up.full_name, up.username, au.email)::text as full_name,
    au.created_at
  FROM auth.users au
  LEFT JOIN user_profiles up ON au.id = up.id
  WHERE 
    CASE 
      WHEN p_search IS NOT NULL AND p_search != '' THEN
        (au.email ILIKE '%' || p_search || '%' OR 
         up.username ILIKE '%' || p_search || '%' OR
         up.full_name ILIKE '%' || p_search || '%')
      ELSE true
    END
  ORDER BY au.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;