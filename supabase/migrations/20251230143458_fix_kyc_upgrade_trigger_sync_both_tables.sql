/*
  # Fix KYC Upgrade Trigger to Sync Both Tables

  1. Changes
    - Updates both user_profiles AND kyc_verifications when documents are verified
    - Ensures consistent status across both tables
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
      -- Upgrade to level 3 (advanced) for selfie verification
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
      -- Upgrade to level 2 (intermediate) for ID verification
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
