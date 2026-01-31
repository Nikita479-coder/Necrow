/*
  # Fix award_kyc_bonus Parameter Order

  ## Problem
  The award_kyc_bonus function was calling award_locked_bonus with incorrect parameter order:
  - Passing (user_id, bonus_type_id, amount, expiry_days, notes)
  - Expected (user_id, bonus_type_id, amount, awarded_by, notes, expiry_days)

  ## Solution
  Update the function call to use correct parameter order with named parameters
  for clarity and to prevent future issues.

  ## Changes
  - Fix parameter order in award_locked_bonus call
  - Use named parameters for clarity
  - awarded_by should be NULL for self-claimed/auto-awarded bonuses
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

  -- Call with correct parameter order using named parameters
  v_result := award_locked_bonus(
    p_user_id := p_user_id,
    p_bonus_type_id := v_bonus_type.id,
    p_amount := v_bonus_type.default_amount,
    p_awarded_by := NULL,  -- NULL = auto-awarded/self-claimed
    p_notes := 'KYC Verification Bonus - Auto-awarded on KYC approval',
    p_expiry_days := COALESCE(v_bonus_type.expiry_days, 7)
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