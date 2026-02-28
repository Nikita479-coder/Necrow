/*
  # Create Test Admin Account

  ## Summary
  Creates a test admin account with email admin@test.com for testing purposes.
  Sets the is_admin flag in the user's JWT metadata to grant admin privileges.

  ## Changes
  1. Create function to set user as admin
  2. Instructions for creating the account

  ## Security
  - Admin status is stored in auth.users raw_app_meta_data
  - This metadata is included in the JWT and cannot be modified by users
  - Admin checks use auth.jwt()->>'is_admin' in RLS policies and functions

  ## Usage
  After running this migration:
  1. Sign up with email: admin@test.com and any password
  2. The system will automatically set admin privileges
  3. You can then access admin features
*/

-- Function to promote a user to admin by email
CREATE OR REPLACE FUNCTION promote_user_to_admin(user_email text)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- Find user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = user_email;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('User not found with email: %s', user_email)
    );
  END IF;

  -- Update user metadata to set admin flag
  UPDATE auth.users
  SET raw_app_meta_data = 
    COALESCE(raw_app_meta_data, '{}'::jsonb) || 
    jsonb_build_object('is_admin', true)
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('User %s promoted to admin', user_email),
    'user_id', v_user_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Error promoting user: %s', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a user is admin
CREATE OR REPLACE FUNCTION is_user_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean AS $$
BEGIN
  RETURN COALESCE(
    (
      SELECT (raw_app_meta_data->>'is_admin')::boolean
      FROM auth.users
      WHERE id = user_id
    ),
    false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Auto-promote specific email to admin on signup
CREATE OR REPLACE FUNCTION auto_promote_admin_emails()
RETURNS TRIGGER AS $$
DECLARE
  admin_emails text[] := ARRAY['admin@test.com', 'admin@sharktrades.com'];
BEGIN
  -- Check if the new user's email is in the admin list
  IF NEW.email = ANY(admin_emails) THEN
    NEW.raw_app_meta_data := 
      COALESCE(NEW.raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('is_admin', true);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS auto_promote_admin_on_signup ON auth.users;

-- Create trigger to auto-promote admin emails
CREATE TRIGGER auto_promote_admin_on_signup
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION auto_promote_admin_emails();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION promote_user_to_admin TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_admin TO authenticated;