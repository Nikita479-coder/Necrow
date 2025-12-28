/*
  # Add Admin Update Policy for User Profiles

  1. Security Changes
    - Add policy allowing admins to update any user profile
    - This enables admin KYC approval functionality

  2. Notes
    - Admins are identified by app_metadata.is_admin = true
    - This fixes the issue where admin KYC approvals weren't persisting
*/

CREATE POLICY "Admins can update any profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (
    COALESCE(((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text)::boolean, false) = true
  )
  WITH CHECK (
    COALESCE(((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text)::boolean, false) = true
  );