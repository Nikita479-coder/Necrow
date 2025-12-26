/*
  # Fix verify_email_code function

  1. Problem
    - The function tries to update user_profiles using email column
    - The user_profiles table does not have an email column
    - The user profile may not exist yet at verification time

  2. Solution
    - Remove the UPDATE to user_profiles from the function
    - The email_verified flag will be set by the frontend after signup completes
*/

CREATE OR REPLACE FUNCTION public.verify_email_code(p_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification record;
BEGIN
  SELECT * INTO v_verification
  FROM public.email_verification_codes
  WHERE email = lower(p_email)
    AND verified_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_verification IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No verification code found. Please request a new code.'
    );
  END IF;

  IF v_verification.attempts >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Too many failed attempts. Please request a new code.'
    );
  END IF;

  IF v_verification.expires_at < now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Verification code has expired. Please request a new code.'
    );
  END IF;

  IF v_verification.code != p_code THEN
    UPDATE public.email_verification_codes
    SET attempts = attempts + 1
    WHERE id = v_verification.id;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid verification code. Please try again.',
      'attempts_remaining', 5 - v_verification.attempts - 1
    );
  END IF;

  UPDATE public.email_verification_codes
  SET verified_at = now()
  WHERE id = v_verification.id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Email verified successfully'
  );
END;
$$;