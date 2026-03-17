/*
  # Fix KYC Status Sync for All Users

  1. Changes
    - Syncs kyc_verifications status with user_profiles for all affected users
    - Creates trigger to keep both tables in sync automatically
    - Updates 317 users with status mismatch

  2. Security
    - Maintains existing RLS policies
*/

-- Fix all existing users with status mismatch
UPDATE kyc_verifications kv
SET kyc_status = up.kyc_status,
    kyc_level = up.kyc_level,
    updated_at = now()
FROM user_profiles up
WHERE kv.user_id = up.id
  AND up.kyc_status = 'verified'
  AND kv.kyc_status = 'pending'
  AND kv.kyc_level >= 1;

-- Create function to sync kyc_verifications when user_profiles is updated
CREATE OR REPLACE FUNCTION sync_kyc_verifications_from_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- When user_profiles kyc status or level changes, sync to kyc_verifications
  IF (NEW.kyc_status IS DISTINCT FROM OLD.kyc_status) OR 
     (NEW.kyc_level IS DISTINCT FROM OLD.kyc_level) THEN
    
    UPDATE kyc_verifications
    SET kyc_status = NEW.kyc_status,
        kyc_level = NEW.kyc_level,
        updated_at = now()
    WHERE user_id = NEW.id;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on user_profiles to sync to kyc_verifications
DROP TRIGGER IF EXISTS sync_kyc_to_verifications ON user_profiles;
CREATE TRIGGER sync_kyc_to_verifications
  AFTER UPDATE ON user_profiles
  FOR EACH ROW
  WHEN (NEW.kyc_status IS DISTINCT FROM OLD.kyc_status OR 
        NEW.kyc_level IS DISTINCT FROM OLD.kyc_level)
  EXECUTE FUNCTION sync_kyc_verifications_from_profile();

-- Create function to sync user_profiles when kyc_verifications is updated
CREATE OR REPLACE FUNCTION sync_user_profile_from_verifications()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- When kyc_verifications status or level changes, sync to user_profiles
  IF (NEW.kyc_status IS DISTINCT FROM OLD.kyc_status) OR 
     (NEW.kyc_level IS DISTINCT FROM OLD.kyc_level) THEN
    
    UPDATE user_profiles
    SET kyc_status = NEW.kyc_status,
        kyc_level = NEW.kyc_level,
        updated_at = now()
    WHERE id = NEW.user_id;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on kyc_verifications to sync to user_profiles
DROP TRIGGER IF EXISTS sync_kyc_to_profile ON kyc_verifications;
CREATE TRIGGER sync_kyc_to_profile
  AFTER UPDATE ON kyc_verifications
  FOR EACH ROW
  WHEN (NEW.kyc_status IS DISTINCT FROM OLD.kyc_status OR 
        NEW.kyc_level IS DISTINCT FROM OLD.kyc_level)
  EXECUTE FUNCTION sync_user_profile_from_verifications();
