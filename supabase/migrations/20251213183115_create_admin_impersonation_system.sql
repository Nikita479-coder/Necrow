/*
  # Admin User Impersonation System
  
  1. New Tables
    - `admin_impersonation_sessions` - Tracks when admins log in as users
      - `id` (uuid, primary key)
      - `admin_id` (uuid) - The admin performing impersonation
      - `target_user_id` (uuid) - The user being impersonated
      - `token` (text) - Unique impersonation token
      - `expires_at` (timestamptz) - When the token expires
      - `used_at` (timestamptz) - When the token was used
      - `ip_address` (text) - IP address of the request
      - `user_agent` (text) - Browser user agent
      - `created_at` (timestamptz)
  
  2. New Permissions
    - `login_as_user` permission added to admin_permissions
  
  3. Security
    - RLS enabled on impersonation_sessions
    - Only admins with permission can create impersonation tokens
    - All impersonation attempts are logged
*/

CREATE TABLE IF NOT EXISTS admin_impersonation_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  target_user_id uuid NOT NULL REFERENCES auth.users(id),
  token text UNIQUE NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '5 minutes'),
  used_at timestamptz,
  ip_address text,
  user_agent text,
  reason text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE admin_impersonation_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view impersonation sessions"
  ON admin_impersonation_sessions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can create impersonation sessions"
  ON admin_impersonation_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
    AND admin_id = auth.uid()
  );

INSERT INTO admin_permissions (code, name, description, category)
VALUES (
  'login_as_user',
  'Login As User',
  'Ability to impersonate and login as any user for support purposes',
  'users'
) ON CONFLICT (code) DO NOTHING;

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
  v_has_permission boolean;
  v_is_super_admin boolean;
BEGIN
  v_admin_id := auth.uid();
  
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  SELECT is_admin, is_super_admin INTO v_has_permission, v_is_super_admin
  FROM user_profiles WHERE id = v_admin_id;
  
  IF NOT COALESCE(v_has_permission, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  IF NOT COALESCE(v_is_super_admin, false) THEN
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
    
    IF NOT v_has_permission THEN
      RETURN jsonb_build_object('success', false, 'error', 'You do not have permission to login as users');
    END IF;
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

CREATE OR REPLACE FUNCTION validate_impersonation_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session admin_impersonation_sessions%ROWTYPE;
  v_target_email text;
BEGIN
  SELECT * INTO v_session
  FROM admin_impersonation_sessions
  WHERE token = p_token
  AND used_at IS NULL
  AND expires_at > now();
  
  IF v_session.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired token');
  END IF;
  
  UPDATE admin_impersonation_sessions
  SET used_at = now()
  WHERE id = v_session.id;
  
  SELECT email INTO v_target_email
  FROM auth.users WHERE id = v_session.target_user_id;
  
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details
  ) VALUES (
    v_session.admin_id,
    'impersonation_token_used',
    v_session.target_user_id,
    jsonb_build_object(
      'session_id', v_session.id,
      'target_email', v_target_email
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'target_user_id', v_session.target_user_id,
    'target_email', v_target_email,
    'admin_id', v_session.admin_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_impersonation_history(p_limit int DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid;
  v_is_admin boolean;
BEGIN
  v_admin_id := auth.uid();
  
  SELECT is_admin INTO v_is_admin
  FROM user_profiles WHERE id = v_admin_id;
  
  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'sessions', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', ais.id,
          'admin_id', ais.admin_id,
          'admin_email', admin_user.email,
          'target_user_id', ais.target_user_id,
          'target_email', target_user.email,
          'token', substring(ais.token, 1, 8) || '...',
          'expires_at', ais.expires_at,
          'used_at', ais.used_at,
          'reason', ais.reason,
          'created_at', ais.created_at
        ) ORDER BY ais.created_at DESC
      ), '[]'::jsonb)
      FROM admin_impersonation_sessions ais
      JOIN auth.users admin_user ON ais.admin_id = admin_user.id
      JOIN auth.users target_user ON ais.target_user_id = target_user.id
      LIMIT p_limit
    )
  );
END;
$$;

CREATE INDEX IF NOT EXISTS idx_impersonation_token ON admin_impersonation_sessions(token);
CREATE INDEX IF NOT EXISTS idx_impersonation_admin ON admin_impersonation_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_target ON admin_impersonation_sessions(target_user_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_expires ON admin_impersonation_sessions(expires_at) WHERE used_at IS NULL;
