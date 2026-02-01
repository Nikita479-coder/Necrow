/*
  # Add Account Suspension Fields
  
  Adds columns to user_profiles to support account suspension functionality.
*/

ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS is_suspended boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS suspension_reason text,
ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
ADD COLUMN IF NOT EXISTS suspended_by uuid REFERENCES auth.users(id);
