/*
  # Create bulk user auth info function

  1. New Functions
    - `get_user_auth_info_bulk(uuid[])` - Returns email and last_sign_in_at for an array of user IDs
  
  2. Security
    - Only accessible to admin/staff users
    - Uses SECURITY DEFINER to access auth.users
*/

CREATE OR REPLACE FUNCTION get_user_auth_info_bulk(user_ids uuid[])
RETURNS TABLE(id uuid, email text, last_sign_in_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_admin boolean;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND admin_staff.is_active = true
    );
  END IF;

  IF NOT is_admin THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT au.id, au.email::text, au.last_sign_in_at
  FROM auth.users au
  WHERE au.id = ANY(user_ids);
END;
$$;
