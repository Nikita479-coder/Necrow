/*
  # Add Admin Policies for Traders Table

  1. Changes
    - Add admin INSERT policy for traders table
    - Add admin UPDATE policy for traders table
    - Add admin DELETE policy for traders table

  2. Security
    - Only users with is_admin = true can manage traders
    - Regular users can still view traders (existing policy)
*/

-- Allow admins to insert traders
CREATE POLICY "Admins can insert traders"
  ON traders FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

-- Allow admins to update traders
CREATE POLICY "Admins can update traders"
  ON traders FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()));

-- Allow admins to delete traders
CREATE POLICY "Admins can delete traders"
  ON traders FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));
