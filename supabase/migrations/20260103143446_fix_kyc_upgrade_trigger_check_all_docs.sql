/*
  # Fix KYC Level Upgrade Trigger - Check All Documents

  1. Problem
    - Current trigger only checks the document being verified
    - Doesn't consider if user already has other required documents verified
    - User with verified ID + verified selfie should be Level 3

  2. Solution
    - When any document is verified, check ALL user's documents
    - Upgrade to Level 3 if user has verified selfie AND verified ID document
    - Upgrade to Level 2 if user has verified ID document (no selfie yet)
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_upgrade_kyc_on_verification ON kyc_documents;
DROP FUNCTION IF EXISTS upgrade_kyc_level_on_verification();

-- Create improved function that checks all user documents
CREATE OR REPLACE FUNCTION upgrade_kyc_level_on_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_has_verified_id BOOLEAN;
  v_has_verified_selfie BOOLEAN;
  v_target_level INTEGER;
BEGIN
  -- Only proceed if the document is being marked as verified
  IF NEW.verified = true AND (TG_OP = 'INSERT' OR OLD.verified IS DISTINCT FROM true) THEN
    
    -- Check if user has verified ID document
    SELECT EXISTS (
      SELECT 1 FROM kyc_documents
      WHERE user_id = NEW.user_id
      AND document_type IN ('id_front', 'id_back', 'passport', 'drivers_license')
      AND verified = true
    ) INTO v_has_verified_id;
    
    -- Check if user has verified selfie
    SELECT EXISTS (
      SELECT 1 FROM kyc_documents
      WHERE user_id = NEW.user_id
      AND document_type = 'selfie'
      AND verified = true
    ) INTO v_has_verified_selfie;
    
    -- Determine target KYC level
    IF v_has_verified_id AND v_has_verified_selfie THEN
      v_target_level := 3;
    ELSIF v_has_verified_id THEN
      v_target_level := 2;
    ELSE
      v_target_level := 1;
    END IF;
    
    -- Update user_profiles if level should increase
    UPDATE user_profiles
    SET kyc_level = v_target_level,
        kyc_status = CASE 
          WHEN v_target_level >= 3 THEN 'verified'
          WHEN v_target_level = 2 THEN 'verified'
          ELSE kyc_status
        END,
        updated_at = now()
    WHERE id = NEW.user_id
    AND COALESCE(kyc_level, 0) < v_target_level;
    
    -- Update kyc_verifications if level should increase
    UPDATE kyc_verifications
    SET kyc_level = v_target_level,
        kyc_status = CASE 
          WHEN v_target_level >= 3 THEN 'verified'
          WHEN v_target_level = 2 THEN 'verified'
          ELSE kyc_status
        END,
        updated_at = now()
    WHERE user_id = NEW.user_id
    AND COALESCE(kyc_level, 0) < v_target_level;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for both INSERT and UPDATE
CREATE TRIGGER trigger_upgrade_kyc_on_verification
  AFTER INSERT OR UPDATE ON kyc_documents
  FOR EACH ROW
  EXECUTE FUNCTION upgrade_kyc_level_on_verification();
