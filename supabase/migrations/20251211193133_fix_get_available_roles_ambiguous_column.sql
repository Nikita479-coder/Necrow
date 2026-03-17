/*
  # Fix get_available_roles ambiguous column reference
  
  ## Issue
  The `get_available_roles` function has an ambiguous 'id' column reference because
  RETURNS TABLE creates implicit variables that conflict with table column names.
  
  ## Solution
  Fully qualify all column references and use explicit aliases in the GROUP BY.
*/

-- Drop and recreate the function with explicit column qualifiers
CREATE OR REPLACE FUNCTION get_available_roles()
RETURNS TABLE (
  id uuid,
  name text,
  description text,
  permission_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only super admins or active staff can view roles
  IF NOT is_super_admin(auth.uid()) AND NOT EXISTS (
    SELECT 1 FROM admin_staff WHERE admin_staff.id = auth.uid() AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Access denied.';
  END IF;
  
  RETURN QUERY
  SELECT 
    r.id as id,
    r.name as name,
    r.description as description,
    COUNT(rp.permission_id)::bigint as permission_count
  FROM admin_roles r
  LEFT JOIN admin_role_permissions rp ON r.id = rp.role_id
  GROUP BY r.id, r.name, r.description
  ORDER BY r.name;
END;
$$;
