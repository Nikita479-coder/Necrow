/*
  # Create admin_list_all_users function
  
  1. New Functions
    - `admin_list_all_users` - Lists all users with their profile information for admin use
      - Returns user_id, email, username, full_name
      - Supports search by email or username
      - Pagination support
      - Admin-only access
  
  2. Security
    - Function only accessible by admin users
    - Uses security definer to access auth.users table
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
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT 
    au.id as user_id,
    au.email,
    COALESCE(up.username, au.email) as username,
    up.full_name,
    au.created_at
  FROM auth.users au
  LEFT JOIN user_profiles up ON au.id = up.id
  WHERE 
    CASE 
      WHEN p_search IS NOT NULL THEN
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