/*
  # Fix Impersonation Function - Super Admin Check
  
  The create_impersonation_token function was referencing a non-existent 
  is_super_admin column on user_profiles. This migration fixes it to:
  - Check for super admin via admin_staff_roles table
  - Fall back to is_admin = true as the primary admin check
*/

CREATE OR REPLACE FUNCTION create_impersonation_token(
  p_target_user_id uuid,
  p_reason text DEFAULT NULL,
  p_ip_address text DEFAULT NULL,
  p_user_agent text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_token text;
  v_session_id uuid;
  v_target_email text;
  v_has_permission boolean := false;
  v_is_admin boolean := false;
  v_is_super_admin boolean := false;
BEGIN
  v_admin_id := auth.uid();
  
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  SELECT is_admin INTO v_is_admin
  FROM user_profiles WHERE id = v_admin_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized - must be an admin');
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM admin_staff_roles asr
    JOIN admin_roles ar ON asr.role_id = ar.id
    WHERE asr.user_id = v_admin_id
    AND ar.name = 'Super Admin'
  ) INTO v_is_super_admin;
  
  IF v_is_super_admin THEN
    v_has_permission := true;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM admin_staff_roles asr
      JOIN admin_role_permissions arp ON asr.role_id = arp.role_id
      JOIN admin_permissions ap ON arp.permission_id = ap.id
      WHERE asr.user_id = v_admin_id
      AND ap.code = 'login_as_user'
      UNION
      SELECT 1 FROM admin_staff_permission_overrides aspo
      JOIN admin_permissions ap ON aspo.permission_id = ap.id
      WHERE aspo.user_id = v_admin_id
      AND ap.code = 'login_as_user'
      AND aspo.granted = true
    ) INTO v_has_permission;
  END IF;
  
  IF NOT v_has_permission THEN
    RETURN jsonb_build_object('success', false, 'error', 'You do not have permission to login as users');
  END IF;
  
  SELECT email INTO v_target_email
  FROM auth.users WHERE id = p_target_user_id;
  
  IF v_target_email IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target user not found');
  END IF;
  
  v_token := encode(gen_random_bytes(32), 'hex');
  
  INSERT INTO admin_impersonation_sessions (
    admin_id,
    target_user_id,
    token,
    expires_at,
    ip_address,
    user_agent,
    reason
  ) VALUES (
    v_admin_id,
    p_target_user_id,
    v_token,
    now() + interval '5 minutes',
    p_ip_address,
    p_user_agent,
    p_reason
  )
  RETURNING id INTO v_session_id;
  
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    v_admin_id,
    'impersonation_token_created',
    p_target_user_id,
    jsonb_build_object(
      'session_id', v_session_id,
      'target_email', v_target_email,
      'reason', p_reason,
      'expires_at', (now() + interval '5 minutes')::text
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'token', v_token,
    'session_id', v_session_id,
    'target_email', v_target_email,
    'expires_at', (now() + interval '5 minutes')::text
  );
END;
$$;
