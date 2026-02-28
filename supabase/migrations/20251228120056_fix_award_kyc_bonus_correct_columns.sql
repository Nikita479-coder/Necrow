/*
  # Fix award_kyc_bonus Function with Correct Columns

  1. Fix
    - Use bonus_type_name instead of bonus_name
    - Include bonus_type_id
    - Include awarded_by (use system/user_id for automated bonuses)
*/

CREATE OR REPLACE FUNCTION public.award_kyc_bonus(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_locked_bonus_id uuid;
  v_user_profile record;
BEGIN
  -- Check if already awarded
  SELECT * INTO v_tracking
  FROM public.signup_bonus_tracking
  WHERE user_id = p_user_id;
  
  IF v_tracking IS NULL THEN
    -- Create tracking record if missing
    INSERT INTO public.signup_bonus_tracking (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_tracking;
  END IF;
  
  IF v_tracking.kyc_bonus_awarded THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus has already been awarded'
    );
  END IF;
  
  -- Get bonus type
  SELECT * INTO v_bonus_type
  FROM public.bonus_types
  WHERE name = 'KYC Verification Bonus'
    AND is_active = true;
    
  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus type not found or inactive'
    );
  END IF;
  
  -- Get user profile for name
  SELECT * INTO v_user_profile
  FROM public.user_profiles
  WHERE id = p_user_id;
  
  -- Create locked bonus
  INSERT INTO public.locked_bonuses (
    user_id,
    original_amount,
    current_amount,
    bonus_type_id,
    bonus_type_name,
    awarded_by,
    expires_at
  ) VALUES (
    p_user_id,
    v_bonus_type.default_amount,
    v_bonus_type.default_amount,
    v_bonus_type.id,
    v_bonus_type.name,
    p_user_id,
    now() + (v_bonus_type.expiry_days || ' days')::interval
  )
  RETURNING id INTO v_locked_bonus_id;
  
  -- Update tracking
  UPDATE public.signup_bonus_tracking
  SET 
    kyc_bonus_awarded = true,
    kyc_bonus_awarded_at = now(),
    kyc_bonus_amount = v_bonus_type.default_amount
  WHERE user_id = p_user_id;
  
  -- Create notification
  INSERT INTO public.notifications (user_id, notification_type, title, message)
  VALUES (
    p_user_id,
    'bonus',
    'KYC Verification Bonus Awarded!',
    'Congratulations! You have received $' || v_bonus_type.default_amount || ' in locked trading credit. This bonus is valid for 7 days and can be used for futures trading. Only profits can be withdrawn.'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'bonus_amount', v_bonus_type.default_amount,
    'locked_bonus_id', v_locked_bonus_id,
    'expires_at', now() + (v_bonus_type.expiry_days || ' days')::interval
  );
END;
$$;
