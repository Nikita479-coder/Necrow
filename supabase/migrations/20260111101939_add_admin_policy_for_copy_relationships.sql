/*
  # Add Admin Policy for Copy Relationships

  1. Security Changes
    - Add SELECT policy for admins to view all copy relationships
    - This allows the admin panel to see all copy traders for each trader

  2. Notes
    - Uses is_user_admin() helper function to check admin status
*/

-- Add admin read policy for copy_relationships
CREATE POLICY "Admins can view all copy relationships"
  ON copy_relationships
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );
