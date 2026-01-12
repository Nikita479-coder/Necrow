/*
  # Fix Ambiguous Column Reference in get_all_staff

  ## Issue
  The `get_all_staff` function has an ambiguous column reference for "username"
  which could refer to either a PL/pgSQL variable or a table column.

  ## Solution
  Properly qualify all column references with table aliases to avoid ambiguity.
*/

CREATE OR REPLACE FUNCTION get_all_staff()
RETURNS TABLE (
  id uuid,
  email text,
  username text,
  full_name text,
  role_id uuid,
  role_name text,
  is_active boolean,
  created_at timestamptz,
  created_by_username text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_super_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Super admin privileges required.';
  END IF;
  
  RETURN QUERY
  SELECT 
    s.id,
    COALESCE(au.email, 'N/A')::text as email,
    COALESCE(up.username, 'No username')::text as username,
    up.full_name::text,
    s.role_id,
    r.name::text as role_name,
    s.is_active,
    s.created_at,
    (SELECT up2.username FROM user_profiles up2 WHERE up2.id = s.created_by)::text as created_by_username
  FROM admin_staff s
  JOIN admin_roles r ON s.role_id = r.id
  LEFT JOIN user_profiles up ON s.id = up.id
  LEFT JOIN auth.users au ON s.id = au.id
  ORDER BY s.created_at DESC;
END;
$$;
