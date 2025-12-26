/*
  # Create simplified admin user listing function
  
  1. Changes
    - Recreate function with better error handling
    - Return empty array instead of raising exception if not admin
    - Make it more permissive for troubleshooting
  
  2. Security
    - Still checks admin status
    - Returns empty results for non-admins
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
DECLARE
  is_user_admin boolean;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO is_user_admin
  FROM user_profiles 
  WHERE id = auth.uid();
  
  -- Return empty result if not admin
  IF is_user_admin IS NULL OR is_user_admin = false THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    au.id as user_id,
    au.email,
    COALESCE(up.username, au.email) as username,
    COALESCE(up.full_name, up.username, au.email) as full_name,
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