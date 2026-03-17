/*
  # Fix KYC Level Upgrade Trigger
  
  1. Problem
    - Trigger only fires on UPDATE, not INSERT
    - Documents inserted with verified=true don't trigger upgrade
  
  2. Solution
    - Add INSERT trigger to also upgrade KYC level
    - Update function to handle INSERT case
*/

-- Drop existing trigger
DROP TRIGGER IF EXISTS trigger_upgrade_kyc_on_verification ON kyc_documents;

-- Create improved function that handles both INSERT and UPDATE
CREATE OR REPLACE FUNCTION upgrade_kyc_level_on_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  -- For INSERT: check if new doc is verified
  -- For UPDATE: check if verified changed from false to true
  IF NEW.verified = true AND (TG_OP = 'INSERT' OR OLD.verified IS NULL OR OLD.verified = false) THEN
    IF NEW.document_type = 'selfie' THEN
      UPDATE user_profiles
      SET kyc_level = 3,
          kyc_status = 'verified',
          updated_at = now()
      WHERE id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 3);

      UPDATE kyc_verifications
      SET kyc_level = 3,
          kyc_status = 'verified',
          updated_at = now()
      WHERE user_id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 3);

    ELSIF NEW.document_type IN ('id_front', 'id_back', 'passport', 'drivers_license') THEN
      UPDATE user_profiles
      SET kyc_level = GREATEST(COALESCE(kyc_level, 0), 2),
          kyc_status = 'verified',
          updated_at = now()
      WHERE id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 2);

      UPDATE kyc_verifications
      SET kyc_level = GREATEST(COALESCE(kyc_level, 0), 2),
          kyc_status = 'verified',
          updated_at = now()
      WHERE user_id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 2);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for both INSERT and UPDATE
CREATE TRIGGER trigger_upgrade_kyc_on_verification
  AFTER INSERT OR UPDATE ON kyc_documents
  FOR EACH ROW
  EXECUTE FUNCTION upgrade_kyc_level_on_verification();
