/*
  # Fix KYC Bonus to Use Proper Locked Bonus System

  1. Changes
    - Updates award_kyc_bonus to use the award_locked_bonus function
    - Ensures volume requirements and 10-minute duration are applied
    - KYC bonus type is already active
*/

CREATE OR REPLACE FUNCTION award_kyc_bonus(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_result jsonb;
BEGIN
  SELECT * INTO v_tracking
  FROM signup_bonus_tracking
  WHERE user_id = p_user_id;

  IF v_tracking IS NULL THEN
    INSERT INTO signup_bonus_tracking (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_tracking;
  END IF;

  IF v_tracking.kyc_bonus_awarded THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus has already been awarded'
    );
  END IF;

  SELECT * INTO v_bonus_type
  FROM bonus_types
  WHERE name = 'KYC Verification Bonus'
  AND is_active = true;

  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus type not found or inactive'
    );
  END IF;

  -- Use the proper award_locked_bonus function with volume requirements
  v_result := award_locked_bonus(
    p_user_id,
    v_bonus_type.id,
    v_bonus_type.default_amount,
    COALESCE(v_bonus_type.expiry_days, 7),
    'KYC Verification Bonus - Auto-awarded on KYC approval'
  );

  IF (v_result->>'success')::boolean THEN
    UPDATE signup_bonus_tracking
    SET 
      kyc_bonus_awarded = true,
      kyc_bonus_awarded_at = now(),
      kyc_bonus_amount = v_bonus_type.default_amount
    WHERE user_id = p_user_id;
  END IF;

  RETURN v_result;
END;
$$;

-- Ensure the KYC bonus type is active with proper settings
UPDATE bonus_types 
SET 
  is_active = true,
  default_amount = 20.00,
  expiry_days = 7
WHERE name = 'KYC Verification Bonus';
