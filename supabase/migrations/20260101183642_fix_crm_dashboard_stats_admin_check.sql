/*
  # Fix CRM Dashboard Stats Admin Check
  
  1. Problem
    - The get_crm_dashboard_stats function returns all zeros because check_admin_permission
      only checks JWT app_metadata.is_admin, which may not be set
    - Users with is_admin=true in user_profiles are not being recognized
  
  2. Solution
    - Update the function to also check user_profiles.is_admin as a fallback
*/

CREATE OR REPLACE FUNCTION check_admin_permission(p_permission_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN 
    RETURN true; 
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RETURN true;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM admin_staff s 
    JOIN admin_role_permissions rp ON s.role_id = rp.role_id 
    JOIN admin_permissions p ON rp.permission_id = p.id 
    WHERE s.id = auth.uid() 
    AND s.is_active = true 
    AND p.code = p_permission_code
  );
END;
$$;
