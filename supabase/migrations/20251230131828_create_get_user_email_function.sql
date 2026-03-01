/*
  # Create Get User Email Function for Admin

  1. New Function
    - `get_user_email_for_admin(p_user_id uuid)` - Returns email for a user
    - Uses SECURITY DEFINER to access auth.users table
    - Only accessible by admins

  2. Security
    - Function checks if caller is admin before returning data
    - Returns NULL if not admin or user not found
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
  IF NOT is_user_admin() THEN
    RETURN NULL;
  END IF;

  SELECT au.email INTO v_email
  FROM auth.users au
  WHERE au.id = p_user_id;

  RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_email_for_admin(uuid) TO authenticated;
