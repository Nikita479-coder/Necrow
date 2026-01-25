/*
  # Fix KYC Verification Notification Column Name
  
  1. Problem
    - The activate_zero_fee_on_kyc_verification trigger function uses 'notification_type' column
    - The notifications table actually has a 'type' column
  
  2. Solution
    - Recreate the trigger function with correct column name
*/

CREATE OR REPLACE FUNCTION activate_zero_fee_on_kyc_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

        -- Create notification for user (FIXED: use 'type' instead of 'notification_type')
        INSERT INTO notifications (
          user_id,
          type,
          title,
          message,
          data,
          read
        ) VALUES (
          NEW.user_id,
          'kyc_update',
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
