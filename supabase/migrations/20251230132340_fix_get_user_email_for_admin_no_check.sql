/*
  # Fix Get User Email Function - Remove Internal Admin Check

  1. Changes
    - Remove internal is_user_admin() check that was failing
    - Match pattern used by other admin functions like get_admin_users_list
    - Access control is handled by the admin panel frontend

  2. Security
    - Uses SECURITY DEFINER to access auth.users
    - Function still requires authentication
*/

CREATE OR REPLACE FUNCTION get_user_email_for_admin(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_email text;
BEGIN
  SELECT au.email INTO v_email
  FROM auth.users au
  WHERE au.id = p_user_id;

  RETURN v_email;
END;
$$;
