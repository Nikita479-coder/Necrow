/*
  # Fix Admin Remove Referral - Remove Rebuild Call
  
  Removes the call to non-existent rebuild function
*/

CREATE OR REPLACE FUNCTION admin_remove_referral_relationship(
  admin_user_id uuid,
  target_user_id uuid,
  reason text DEFAULT 'Administrative correction'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  v_old_referrer_id uuid;
  v_old_referrer_email text;
  v_target_email text;
  v_is_exclusive_affiliate boolean;
  v_result jsonb;
BEGIN
  -- Check if admin (direct table check)
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = admin_user_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'Only administrators can remove referral relationships';
  END IF;
  
  -- Get target user info
  SELECT 
    up.referred_by,
    au.email,
    au2.email
  INTO 
    v_old_referrer_id,
    v_target_email,
    v_old_referrer_email
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN auth.users au2 ON au2.id = up.referred_by
  WHERE up.id = target_user_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  IF v_old_referrer_id IS NULL THEN
    RAISE EXCEPTION 'User has no referrer to remove';
  END IF;
  
  -- Check if old referrer is an exclusive affiliate
  SELECT EXISTS(
    SELECT 1 FROM exclusive_affiliates WHERE user_id = v_old_referrer_id
  ) INTO v_is_exclusive_affiliate;
  
  -- Remove the referral relationship
  UPDATE user_profiles
  SET referred_by = NULL
  WHERE id = target_user_id;
  
  -- Update referral stats for old referrer (decrement count)
  UPDATE referral_stats
  SET 
    total_referrals = GREATEST(0, total_referrals - 1),
    updated_at = now()
  WHERE user_id = v_old_referrer_id;
  
  -- If old referrer was an exclusive affiliate, manually update their tier
  IF v_is_exclusive_affiliate THEN
    -- Remove from exclusive affiliate tiers
    DELETE FROM exclusive_affiliate_tiers
    WHERE descendant_id = target_user_id;
  END IF;
  
  -- Create admin audit log (visible only to admins)
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    admin_user_id,
    'remove_referral',
    target_user_id,
    jsonb_build_object(
      'target_email', v_target_email,
      'old_referrer_id', v_old_referrer_id,
      'old_referrer_email', v_old_referrer_email,
      'reason', reason,
      'timestamp', now()
    ),
    NULL
  );
  
  -- Return result
  v_result := jsonb_build_object(
    'success', true,
    'target_email', v_target_email,
    'removed_referrer', v_old_referrer_email,
    'message', 'Referral relationship removed successfully'
  );
  
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_remove_referral_relationship TO authenticated;
