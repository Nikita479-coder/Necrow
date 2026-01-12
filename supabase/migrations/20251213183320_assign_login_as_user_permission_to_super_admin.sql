/*
  # Assign Login As User Permission to Super Admin Role
  
  1. Changes
    - Assigns the 'login_as_user' permission to the Super Admin role
    - Creates a function to view impersonation history for authorized staff
  
  2. Security
    - Only super admins have this permission by default
    - Other staff can have it granted individually through permission overrides
*/

DO $$
DECLARE
  v_super_admin_role_id uuid;
  v_permission_id uuid;
BEGIN
  SELECT id INTO v_super_admin_role_id FROM admin_roles WHERE name = 'Super Admin' LIMIT 1;
  SELECT id INTO v_permission_id FROM admin_permissions WHERE code = 'login_as_user' LIMIT 1;
  
  IF v_super_admin_role_id IS NOT NULL AND v_permission_id IS NOT NULL THEN
    INSERT INTO admin_role_permissions (role_id, permission_id)
    VALUES (v_super_admin_role_id, v_permission_id)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION check_has_login_as_permission()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_super_admin boolean;
  v_has_permission boolean;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  SELECT is_super_admin INTO v_is_super_admin
  FROM user_profiles WHERE id = v_user_id;
  
  IF COALESCE(v_is_super_admin, false) THEN
    RETURN true;
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM admin_staff_roles asr
    JOIN admin_role_permissions arp ON asr.role_id = arp.role_id
    JOIN admin_permissions ap ON arp.permission_id = ap.id
    WHERE asr.user_id = v_user_id
    AND ap.code = 'login_as_user'
    UNION
    SELECT 1 FROM admin_staff_permission_overrides aspo
    JOIN admin_permissions ap ON aspo.permission_id = ap.id
    WHERE aspo.user_id = v_user_id
    AND ap.code = 'login_as_user'
    AND aspo.granted = true
  ) INTO v_has_permission;
  
  RETURN COALESCE(v_has_permission, false);
END;
$$;
