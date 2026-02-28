/*
  # Update KYC Level Constraint

  1. Changes
    - Drop old check constraint on user_profiles.kyc_level (only allowed 0-2)
    - Add new check constraint allowing kyc_level 0-4
    - This enables Advanced (level 3) and Entity (level 4) verification

  2. Security
    - No RLS changes needed
*/

-- Drop the old constraint that only allowed 0-2
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_kyc_level_check;

-- Add new constraint allowing 0-4
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_kyc_level_check 
  CHECK (kyc_level >= 0 AND kyc_level <= 4);
