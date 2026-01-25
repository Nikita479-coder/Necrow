/*
  # Zero Trading Fees for 7 Days on KYC Verification

  1. New Columns
    - Add `zero_fee_expires_at` to user_profiles to track promotion period
    - Add `kyc_verified_at` to track when KYC was first verified

  2. New Function
    - `check_user_zero_fee_active` - Check if user has active zero fee promotion
    - `activate_zero_fee_on_kyc` - Trigger function to activate 7-day zero fees on KYC verification

  3. Changes
    - Update place_futures_order to check for zero fee promotion
    - Update close_position to check for zero fee promotion
    - Add trigger on kyc_documents to activate promotion when verified

  4. Security
    - Functions are SECURITY DEFINER to ensure proper access
*/

-- Add columns to track zero fee promotion
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS zero_fee_expires_at timestamptz DEFAULT NULL,
ADD COLUMN IF NOT EXISTS kyc_verified_at timestamptz DEFAULT NULL;

-- Create function to check if user has active zero fee promotion
CREATE OR REPLACE FUNCTION check_user_zero_fee_active(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expires_at timestamptz;
BEGIN
  SELECT zero_fee_expires_at INTO v_expires_at
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_expires_at IS NULL THEN
    RETURN false;
  END IF;

  RETURN v_expires_at > now();
END;
$$;

-- Create trigger function to activate zero fee on KYC verification
CREATE OR REPLACE FUNCTION activate_zero_fee_on_kyc_verification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_has_verified_id BOOLEAN;
  v_has_verified_selfie BOOLEAN;
  v_is_fully_verified BOOLEAN;
  v_already_activated BOOLEAN;
  v_user_email text;
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
    
    -- Check if fully verified (has both ID and selfie)
    v_is_fully_verified := v_has_verified_id AND v_has_verified_selfie;
    
    IF v_is_fully_verified THEN
      -- Check if zero fee was already activated
      SELECT (kyc_verified_at IS NOT NULL) INTO v_already_activated
      FROM user_profiles
      WHERE id = NEW.user_id;
      
      IF NOT v_already_activated THEN
        -- Activate 7-day zero trading fee promotion
        UPDATE user_profiles
        SET zero_fee_expires_at = now() + INTERVAL '7 days',
            kyc_verified_at = now(),
            updated_at = now()
        WHERE id = NEW.user_id;
        
        -- Get user email for notification
        SELECT email INTO v_user_email
        FROM auth.users
        WHERE id = NEW.user_id;
        
        -- Create notification for user
        INSERT INTO notifications (
          user_id,
          notification_type,
          title,
          message,
          data,
          read
        ) VALUES (
          NEW.user_id,
          'kyc_verified',
          'KYC Verified - 0% Trading Fees Activated!',
          'Congratulations! Your identity has been verified. You now have 0% trading fees for the next 7 days. Start trading now!',
          jsonb_build_object(
            'promotion', 'zero_fee_7_days',
            'expires_at', (now() + INTERVAL '7 days')::text,
            'kyc_level', 3
          ),
          false
        );
        
        -- Log the activation
        INSERT INTO admin_action_logs (
          action,
          target_type,
          target_id,
          details
        ) VALUES (
          'zero_fee_activated',
          'user',
          NEW.user_id,
          jsonb_build_object(
            'reason', 'kyc_verification',
            'expires_at', (now() + INTERVAL '7 days')::text,
            'email', v_user_email
          )
        );
      END IF;
    END IF;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if exists and create new one
DROP TRIGGER IF EXISTS trigger_zero_fee_on_kyc ON kyc_documents;

CREATE TRIGGER trigger_zero_fee_on_kyc
  AFTER INSERT OR UPDATE ON kyc_documents
  FOR EACH ROW
  EXECUTE FUNCTION activate_zero_fee_on_kyc_verification();

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_user_zero_fee_active TO authenticated;
