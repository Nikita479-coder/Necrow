/*
  # Fix Shark Card Application - Correct Column Name

  1. Changes
    - Fix apply_for_shark_card to use user_profiles.id instead of user_profiles.user_id
    - The user_profiles table uses 'id' as the primary key column
*/

-- Recreate apply_for_shark_card function with correct column reference
CREATE OR REPLACE FUNCTION apply_for_shark_card(
  p_full_name text,
  p_country text,
  p_requested_limit numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_application_id uuid;
  v_existing_app uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Check if user already has a pending or approved application
  SELECT application_id INTO v_existing_app
  FROM shark_card_applications
  WHERE user_id = v_user_id
    AND status IN ('pending', 'approved')
  LIMIT 1;
  
  IF v_existing_app IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You already have a pending or approved application');
  END IF;
  
  -- Create application
  INSERT INTO shark_card_applications (
    user_id, full_name, country, requested_limit
  )
  VALUES (
    v_user_id, p_full_name, p_country, p_requested_limit
  )
  RETURNING application_id INTO v_application_id;
  
  -- Create notification for admins
  INSERT INTO notifications (user_id, type, title, message, read)
  SELECT 
    up.id,
    'shark_card_application',
    'New Shark Card Application',
    p_full_name || ' applied for a Shark Card with ' || p_requested_limit || ' USDT limit',
    false
  FROM user_profiles up
  WHERE up.is_admin = true;
  
  RETURN jsonb_build_object(
    'success', true,
    'application_id', v_application_id,
    'message', 'Application submitted successfully'
  );
END;
$$;