/*
  # Add Admin Policies for Wallets

  1. Changes
    - Add admin SELECT policy for wallets table
    - Add admin UPDATE policy for wallets table
    - Allows admins to view and manage all user wallets
  
  2. Security
    - Uses is_user_admin() helper function
    - Only applies to authenticated admin users
*/

-- Allow admins to view all wallets
CREATE POLICY "Admins can view all wallets"
  ON wallets
  FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

-- Allow admins to update all wallets
CREATE POLICY "Admins can update all wallets"
  ON wallets
  FOR UPDATE
  TO authenticated
  USING (is_user_admin(auth.uid()));

-- Allow admins to insert wallets for any user
CREATE POLICY "Admins can insert any wallet"
  ON wallets
  FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin(auth.uid()));