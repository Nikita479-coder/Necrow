/*
  # Create Generic KYC Auto-Bonus Trigger

  1. Changes
    - Replaces the old `award_kyc_bonus` function with a new version that reads from `bonus_types`
      where `auto_trigger_event = 'kyc_verified'` AND `auto_trigger_enabled = true`
    - Uses `signup_bonus_tracking` to prevent duplicate awards (same pattern as before)
    - Awards as locked bonus via `award_locked_bonus()` using the amount and expiry from bonus_types
    - The existing trigger `trigger_award_kyc_bonus` continues to fire on user_profiles update,
      calling `tr_award_kyc_bonus_on_approval()` which calls this updated `award_kyc_bonus()`

  2. Security
    - SECURITY DEFINER with explicit search_path
    - No RLS changes

  3. Important Notes
    - If no bonus_types row has auto_trigger_event='kyc_verified' enabled, no bonus is awarded
    - Admins can disable the KYC auto-bonus entirely by toggling auto_trigger_enabled in CRM
    - Admins can change the amount by updating default_amount in CRM
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
  v_results jsonb := '[]'::jsonb;
  v_any_success boolean := false;
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

  FOR v_bonus_type IN
    SELECT id, name, default_amount, expiry_days, is_locked_bonus
    FROM bonus_types
    WHERE auto_trigger_event = 'kyc_verified'
      AND auto_trigger_enabled = true
      AND is_active = true
  LOOP
    IF v_bonus_type.is_locked_bonus THEN
      v_result := award_locked_bonus(
        p_user_id := p_user_id,
        p_bonus_type_id := v_bonus_type.id,
        p_amount := v_bonus_type.default_amount,
        p_awarded_by := NULL,
        p_notes := v_bonus_type.name || ' - Auto-awarded on KYC approval',
        p_expiry_days := COALESCE(v_bonus_type.expiry_days, 7)
      );
    ELSE
      v_result := award_user_bonus(
        p_user_id := p_user_id,
        p_bonus_type_id := v_bonus_type.id,
        p_amount := v_bonus_type.default_amount,
        p_awarded_by := NULL,
        p_notes := v_bonus_type.name || ' - Auto-awarded on KYC approval',
        p_expiry_days := v_bonus_type.expiry_days
      );
    END IF;

    IF (v_result->>'success')::boolean THEN
      v_any_success := true;
    END IF;

    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'bonus_type', v_bonus_type.name,
        'amount', v_bonus_type.default_amount,
        'result', v_result
      )
    );
  END LOOP;

  IF v_any_success THEN
    UPDATE signup_bonus_tracking
    SET
      kyc_bonus_awarded = true,
      kyc_bonus_awarded_at = now(),
      kyc_bonus_amount = (
        SELECT COALESCE(SUM(default_amount), 0)
        FROM bonus_types
        WHERE auto_trigger_event = 'kyc_verified'
          AND auto_trigger_enabled = true
          AND is_active = true
      )
    WHERE user_id = p_user_id;
  END IF;

  IF jsonb_array_length(v_results) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active auto-triggered KYC bonus types found'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', v_any_success,
    'bonuses_awarded', v_results
  );
END;
$$;
