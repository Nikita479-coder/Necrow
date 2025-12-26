/*
  # Create Admin Staff Management Functions

  ## Description
  This migration creates RPC functions for managing staff accounts and checking permissions.

  ## Functions
  1. get_staff_permissions - Get all permissions for the current user
  2. has_permission - Check if current user has a specific permission
  3. get_all_staff - Get list of all staff members (super admin only)
  4. create_staff_user - Create a new staff account
  5. update_staff_role - Update a staff member's role
  6. toggle_staff_active - Activate/deactivate a staff member
  7. get_available_roles - Get all available roles
*/

-- Function to get current user's permissions
CREATE OR REPLACE FUNCTION get_staff_permissions()
RETURNS TABLE (
  permission_code text,
  permission_name text,
  category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_super_admin boolean;
BEGIN
  v_user_id := auth.uid();
  
  -- Check if super admin first
  SELECT is_admin INTO v_is_super_admin
  FROM user_profiles
  WHERE id = v_user_id;
  
  -- Super admins get all permissions
  IF v_is_super_admin = true THEN
    RETURN QUERY
    SELECT p.code, p.name, p.category
    FROM admin_permissions p
    ORDER BY p.category, p.name;
    RETURN;
  END IF;
  
  -- Staff members get permissions based on their role
  RETURN QUERY
  SELECT p.code, p.name, p.category
  FROM admin_staff s
  JOIN admin_role_permissions rp ON s.role_id = rp.role_id
  JOIN admin_permissions p ON rp.permission_id = p.id
  WHERE s.id = v_user_id
  AND s.is_active = true
  ORDER BY p.category, p.name;
END;
$$;

-- Function to check if user has specific permission
CREATE OR REPLACE FUNCTION has_permission(p_permission_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_super_admin boolean;
  v_has_perm boolean;
BEGIN
  v_user_id := auth.uid();
  
  -- Check if super admin
  SELECT is_admin INTO v_is_super_admin
  FROM user_profiles
  WHERE id = v_user_id;
  
  IF v_is_super_admin = true THEN
    RETURN true;
  END IF;
  
  -- Check staff permissions
  SELECT EXISTS (
    SELECT 1
    FROM admin_staff s
    JOIN admin_role_permissions rp ON s.role_id = rp.role_id
    JOIN admin_permissions p ON rp.permission_id = p.id
    WHERE s.id = v_user_id
    AND s.is_active = true
    AND p.code = p_permission_code
  ) INTO v_has_perm;
  
  RETURN COALESCE(v_has_perm, false);
END;
$$;

-- Function to get all staff members
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
  -- Only super admins can view all staff
  IF NOT is_super_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied. Super admin privileges required.';
  END IF;
  
  RETURN QUERY
  SELECT 
    s.id,
    COALESCE(au.email, 'N/A') as email,
    COALESCE(up.username, 'No username') as username,
    up.full_name,
    s.role_id,
    r.name as role_name,
    s.is_active,
    s.created_at,
    (SELECT username FROM user_profiles WHERE id = s.created_by) as created_by_username
  FROM admin_staff s
  JOIN admin_roles r ON s.role_id = r.id
  LEFT JOIN user_profiles up ON s.id = up.id
  LEFT JOIN auth.users au ON s.id = au.id
  ORDER BY s.created_at DESC;
END;
$$;

-- Function to create a staff user
CREATE OR REPLACE FUNCTION create_staff_user(
  p_user_id uuid,
  p_role_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_role_name text;
BEGIN
  v_admin_id := auth.uid();
  
  -- Only super admins can create staff
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'User not found.');
  END IF;
  
  -- Check if role exists
  SELECT name INTO v_role_name FROM admin_roles WHERE id = p_role_id;
  IF v_role_name IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Role not found.');
  END IF;
  
  -- Check if already staff
  IF EXISTS (SELECT 1 FROM admin_staff WHERE id = p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'User is already a staff member.');
  END IF;
  
  -- Create staff record
  INSERT INTO admin_staff (id, role_id, is_active, created_by)
  VALUES (p_user_id, p_role_id, true, v_admin_id);
  
  -- Log the action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_admin_id,
    'create_staff',
    'Created staff account with role: ' || v_role_name,
    p_user_id,
    json_build_object('role_id', p_role_id, 'role_name', v_role_name)
  );
  
  RETURN json_build_object('success', true, 'message', 'Staff account created successfully.');
END;
$$;

-- Function to update staff role
CREATE OR REPLACE FUNCTION update_staff_role(
  p_staff_id uuid,
  p_new_role_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_old_role_name text;
  v_new_role_name text;
BEGIN
  v_admin_id := auth.uid();
  
  -- Only super admins can update staff
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  -- Get old role name
  SELECT r.name INTO v_old_role_name
  FROM admin_staff s
  JOIN admin_roles r ON s.role_id = r.id
  WHERE s.id = p_staff_id;
  
  IF v_old_role_name IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Staff member not found.');
  END IF;
  
  -- Get new role name
  SELECT name INTO v_new_role_name FROM admin_roles WHERE id = p_new_role_id;
  IF v_new_role_name IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Role not found.');
  END IF;
  
  -- Update role
  UPDATE admin_staff
  SET role_id = p_new_role_id, updated_at = now()
  WHERE id = p_staff_id;
  
  -- Log the action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_admin_id,
    'update_staff_role',
    'Changed role from ' || v_old_role_name || ' to ' || v_new_role_name,
    p_staff_id,
    json_build_object('old_role', v_old_role_name, 'new_role', v_new_role_name)
  );
  
  RETURN json_build_object('success', true, 'message', 'Staff role updated successfully.');
END;
$$;

-- Function to toggle staff active status
CREATE OR REPLACE FUNCTION toggle_staff_active(
  p_staff_id uuid,
  p_is_active boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  v_admin_id := auth.uid();
  
  -- Only super admins can toggle staff status
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  -- Cannot deactivate yourself
  IF p_staff_id = v_admin_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot deactivate your own account.');
  END IF;
  
  -- Update status
  UPDATE admin_staff
  SET is_active = p_is_active, updated_at = now()
  WHERE id = p_staff_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff member not found.');
  END IF;
  
  -- Log the action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id, metadata)
  VALUES (
    v_admin_id,
    CASE WHEN p_is_active THEN 'activate_staff' ELSE 'deactivate_staff' END,
    CASE WHEN p_is_active THEN 'Activated staff account' ELSE 'Deactivated staff account' END,
    p_staff_id,
    json_build_object('is_active', p_is_active)
  );
  
  RETURN json_build_object(
    'success', true, 
    'message', CASE WHEN p_is_active THEN 'Staff activated successfully.' ELSE 'Staff deactivated successfully.' END
  );
END;
$$;

-- Function to get available roles
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
    SELECT 1 FROM admin_staff WHERE id = auth.uid() AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Access denied.';
  END IF;
  
  RETURN QUERY
  SELECT 
    r.id,
    r.name,
    r.description,
    COUNT(rp.permission_id) as permission_count
  FROM admin_roles r
  LEFT JOIN admin_role_permissions rp ON r.id = rp.role_id
  GROUP BY r.id, r.name, r.description
  ORDER BY r.name;
END;
$$;

-- Function to get role permissions
CREATE OR REPLACE FUNCTION get_role_permissions(p_role_id uuid)
RETURNS TABLE (
  permission_code text,
  permission_name text,
  category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT p.code, p.name, p.category
  FROM admin_role_permissions rp
  JOIN admin_permissions p ON rp.permission_id = p.id
  WHERE rp.role_id = p_role_id
  ORDER BY p.category, p.name;
END;
$$;

-- Function to check if user is staff or super admin
CREATE OR REPLACE FUNCTION is_staff_or_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  -- Check super admin
  IF is_super_admin(v_user_id) THEN
    RETURN true;
  END IF;
  
  -- Check staff
  RETURN EXISTS (
    SELECT 1 FROM admin_staff
    WHERE id = v_user_id AND is_active = true
  );
END;
$$;

-- Function to get user's staff info
CREATE OR REPLACE FUNCTION get_my_staff_info()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_super_admin boolean;
  v_staff_record record;
  v_permissions text[];
BEGIN
  v_user_id := auth.uid();
  
  -- Check if super admin
  SELECT is_admin INTO v_is_super_admin
  FROM user_profiles
  WHERE id = v_user_id;
  
  IF v_is_super_admin = true THEN
    -- Get all permissions for super admin
    SELECT array_agg(code) INTO v_permissions FROM admin_permissions;
    
    RETURN json_build_object(
      'is_super_admin', true,
      'is_staff', false,
      'role_name', 'Super Admin',
      'role_id', null,
      'permissions', v_permissions
    );
  END IF;
  
  -- Check if staff
  SELECT 
    s.id,
    s.role_id,
    r.name as role_name,
    s.is_active
  INTO v_staff_record
  FROM admin_staff s
  JOIN admin_roles r ON s.role_id = r.id
  WHERE s.id = v_user_id;
  
  IF v_staff_record IS NULL THEN
    RETURN json_build_object(
      'is_super_admin', false,
      'is_staff', false,
      'role_name', null,
      'role_id', null,
      'permissions', ARRAY[]::text[]
    );
  END IF;
  
  IF NOT v_staff_record.is_active THEN
    RETURN json_build_object(
      'is_super_admin', false,
      'is_staff', true,
      'is_active', false,
      'role_name', v_staff_record.role_name,
      'role_id', v_staff_record.role_id,
      'permissions', ARRAY[]::text[]
    );
  END IF;
  
  -- Get staff permissions
  SELECT array_agg(p.code) INTO v_permissions
  FROM admin_role_permissions rp
  JOIN admin_permissions p ON rp.permission_id = p.id
  WHERE rp.role_id = v_staff_record.role_id;
  
  RETURN json_build_object(
    'is_super_admin', false,
    'is_staff', true,
    'is_active', true,
    'role_name', v_staff_record.role_name,
    'role_id', v_staff_record.role_id,
    'permissions', COALESCE(v_permissions, ARRAY[]::text[])
  );
END;
$$;

-- Function to delete staff member
CREATE OR REPLACE FUNCTION delete_staff_member(p_staff_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
BEGIN
  v_admin_id := auth.uid();
  
  IF NOT is_super_admin(v_admin_id) THEN
    RETURN json_build_object('success', false, 'error', 'Access denied. Super admin privileges required.');
  END IF;
  
  IF p_staff_id = v_admin_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete your own staff record.');
  END IF;
  
  DELETE FROM admin_staff WHERE id = p_staff_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff member not found.');
  END IF;
  
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, target_user_id)
  VALUES (v_admin_id, 'delete_staff', 'Removed staff privileges', p_staff_id);
  
  RETURN json_build_object('success', true, 'message', 'Staff member removed successfully.');
END;
$$;
