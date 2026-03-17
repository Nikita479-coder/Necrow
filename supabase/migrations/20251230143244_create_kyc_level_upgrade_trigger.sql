/*
  # Create KYC Level Upgrade Trigger

  1. New Trigger
    - Automatically upgrades user KYC level when documents are verified
    - Level 2: ID document verified
    - Level 3: Selfie verified (advanced)
*/

CREATE OR REPLACE FUNCTION upgrade_kyc_level_on_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.verified = true AND (OLD.verified IS NULL OR OLD.verified = false) THEN
    IF NEW.document_type = 'selfie' THEN
      UPDATE user_profiles
      SET kyc_level = 3,
          kyc_status = 'verified',
          updated_at = now()
      WHERE id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 3);
    ELSIF NEW.document_type IN ('id_front', 'id_back', 'passport', 'drivers_license') THEN
      UPDATE user_profiles
      SET kyc_level = GREATEST(COALESCE(kyc_level, 0), 2),
          kyc_status = 'verified',
          updated_at = now()
      WHERE id = NEW.user_id
      AND (kyc_level IS NULL OR kyc_level < 2);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_upgrade_kyc_on_verification ON kyc_documents;

CREATE TRIGGER trigger_upgrade_kyc_on_verification
  AFTER UPDATE ON kyc_documents
  FOR EACH ROW
  EXECUTE FUNCTION upgrade_kyc_level_on_verification();
