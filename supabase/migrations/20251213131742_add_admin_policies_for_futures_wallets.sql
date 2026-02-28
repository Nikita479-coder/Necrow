/*
  # Add Admin Policies for Futures Margin Wallets

  1. Changes
    - Add admin SELECT policy for futures_margin_wallets table
    - Add admin UPDATE policy for futures_margin_wallets table
    - Allows admins to view and manage all user futures wallets
  
  2. Security
    - Uses is_user_admin() helper function
    - Only applies to authenticated admin users
*/

-- Allow admins to view all futures margin wallets
CREATE POLICY "Admins can view all futures wallets"
  ON futures_margin_wallets
  FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

-- Allow admins to update all futures margin wallets
CREATE POLICY "Admins can update all futures wallets"
  ON futures_margin_wallets
  FOR UPDATE
  TO authenticated
  USING (is_user_admin(auth.uid()));

-- Allow admins to insert futures wallets for any user
CREATE POLICY "Admins can insert any futures wallet"
  ON futures_margin_wallets
  FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin(auth.uid()));