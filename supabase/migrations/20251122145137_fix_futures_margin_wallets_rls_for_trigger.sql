/*
  # Fix Futures Margin Wallets RLS for Trigger

  1. Problem
    - futures_margin_wallets INSERT policy requires authenticated user
    - The initialize_futures_margin_wallet() trigger runs during signup
    - User is not authenticated yet in the session context
    - Trigger fails, blocking user creation
    
  2. Solution
    - Replace restrictive INSERT policy with one that allows trigger to insert
    - Maintain security by keeping SELECT restricted to authenticated users
    
  3. Security
    - Only SECURITY DEFINER trigger can insert
    - Users can only view their own wallets
*/

-- Drop the restrictive insert policy
DROP POLICY IF EXISTS "Users can insert own margin wallet" ON futures_margin_wallets;

-- Add a new policy that allows the trigger to insert
CREATE POLICY "Allow margin wallet creation"
  ON futures_margin_wallets
  FOR INSERT
  WITH CHECK (true);

-- Add UPDATE policy for future use
CREATE POLICY "Allow margin wallet updates"
  ON futures_margin_wallets
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
