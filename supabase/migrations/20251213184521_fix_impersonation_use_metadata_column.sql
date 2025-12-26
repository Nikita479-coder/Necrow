/*
  # Fix Impersonation Function - Use Correct Column Name
  
  Changes details to metadata for admin_activity_logs
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
    SELECT 1 FROM admin_staff ast
    JOIN admin_roles ar ON ast.role_id = ar.id
    WHERE ast.id = v_admin_id
    AND ar.name = 'Super Admin'
    AND ast.is_active = true
  ) INTO v_is_super_admin;
  
  IF v_is_super_admin THEN
    v_has_permission := true;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM admin_staff ast
      JOIN admin_role_permissions arp ON ast.role_id = arp.role_id
      JOIN admin_permissions ap ON arp.permission_id = ap.id
      WHERE ast.id = v_admin_id
      AND ast.is_active = true
      AND ap.code = 'login_as_user'
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
  
  v_token := md5(random()::text || clock_timestamp()::text || p_target_user_id::text) || 
             md5(random()::text || v_admin_id::text);
  
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
  
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    target_user_id,
    metadata
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
