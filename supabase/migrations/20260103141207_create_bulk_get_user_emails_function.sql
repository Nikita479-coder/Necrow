/*
  # Create Bulk Get User Emails Function
  
  1. Purpose
    - Fetch emails for multiple users in a single query
    - Much faster than calling get_user_email for each user
  
  2. Security
    - Only accessible by admins
*/

CREATE OR REPLACE FUNCTION get_user_emails_bulk(user_ids uuid[])
RETURNS TABLE (user_id uuid, email text)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  is_admin boolean;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND is_active = true
    );
  END IF;
  
  IF NOT is_admin THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT au.id, au.email::text
  FROM auth.users au
  WHERE au.id = ANY(user_ids);
END;
$$;
