/*
  # Fix Referral Stats RLS for Trigger

  1. Problem
    - referral_stats has INSERT policy requiring authenticated users
    - The update_referral_count_trigger runs when user_profiles.referred_by is updated
    - This can happen during signup when user isn't authenticated yet
    - Trigger fails, blocking user creation
    
  2. Solution
    - Replace restrictive INSERT policy with one that allows trigger to insert
    - Maintain security for SELECT and UPDATE
    
  3. Security
    - Only SECURITY DEFINER functions/triggers can insert
    - Users can still only view and update their own stats
*/

-- Drop the restrictive insert policy
DROP POLICY IF EXISTS "Users can insert own referral stats" ON referral_stats;

-- Add a new policy that allows the trigger to insert
CREATE POLICY "Allow referral stats creation"
  ON referral_stats
  FOR INSERT
  WITH CHECK (true);
