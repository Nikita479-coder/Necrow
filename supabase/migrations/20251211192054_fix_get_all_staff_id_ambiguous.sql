/*
  # Fix Ambiguous Column Reference for "id" in get_all_staff

  ## Issue
  The `get_all_staff` function has an ambiguous column reference for "id"
  because the return type column name conflicts with table column names.

  ## Solution
  Rename the output column aliases to avoid conflicts with the return type.
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
DECLARE
  v_staff_id uuid;
  v_email text;
  v_username text;
  v_full_name text;
  v_role_id uuid;
  v_role_name text;
  v_is_active boolean;
  v_created_at timestamptz;
  v_created_by_username text;
BEGIN
  IF NOT is_super_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Super admin privileges required.';
  END IF;
  
  FOR v_staff_id, v_email, v_username, v_full_name, v_role_id, v_role_name, v_is_active, v_created_at, v_created_by_username IN
    SELECT 
      s.id AS staff_id,
      COALESCE(au.email, 'N/A')::text AS staff_email,
      COALESCE(up.username, 'No username')::text AS staff_username,
      up.full_name::text AS staff_full_name,
      s.role_id AS staff_role_id,
      r.name::text AS staff_role_name,
      s.is_active AS staff_is_active,
      s.created_at AS staff_created_at,
      (SELECT up2.username FROM user_profiles up2 WHERE up2.id = s.created_by)::text AS staff_created_by
    FROM admin_staff s
    JOIN admin_roles r ON s.role_id = r.id
    LEFT JOIN user_profiles up ON s.id = up.id
    LEFT JOIN auth.users au ON s.id = au.id
    ORDER BY s.created_at DESC
  LOOP
    id := v_staff_id;
    email := v_email;
    username := v_username;
    full_name := v_full_name;
    role_id := v_role_id;
    role_name := v_role_name;
    is_active := v_is_active;
    created_at := v_created_at;
    created_by_username := v_created_by_username;
    RETURN NEXT;
  END LOOP;
END;
$$;
