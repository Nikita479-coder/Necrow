/*
  # Fix Broadcast Notification Admin Check

  1. Changes
    - Use correct admin_staff column: id instead of user_id
    - Check for super admin via role name instead of is_super_admin column

  2. Security
    - Function validates admin status before sending
*/

CREATE OR REPLACE FUNCTION broadcast_notification_to_all_users(
  p_admin_id uuid,
  p_title text,
  p_message text,
  p_notification_type text DEFAULT 'system',
  p_redirect_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  v_user_count int;
  v_valid_type text;
BEGIN
  -- Check if user is admin (either via user_profiles.is_admin or via admin_staff with super admin role)
  SELECT (
    up.is_admin = true 
    OR EXISTS (
      SELECT 1 FROM admin_staff ast
      JOIN admin_roles ar ON ar.id = ast.role_id
      WHERE ast.id = p_admin_id 
      AND ast.is_active = true
      AND ar.name = 'Super Admin'
    )
  )
  INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = p_admin_id;

  IF NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
  END IF;

  -- Validate and map notification type
  v_valid_type := CASE p_notification_type
    WHEN 'reward' THEN 'reward'
    WHEN 'system' THEN 'system'
    WHEN 'referral_payout' THEN 'referral_payout'
    WHEN 'account_update' THEN 'account_update'
    WHEN 'broadcast' THEN 'broadcast'
    WHEN 'promotion' THEN 'promotion'
    WHEN 'bonus' THEN 'bonus'
    ELSE 'system'
  END;

  -- Insert notifications for all users
  INSERT INTO notifications (user_id, type, title, message, redirect_url, read)
  SELECT 
    up.id,
    v_valid_type,
    p_title,
    p_message,
    p_redirect_url,
    false
  FROM user_profiles up
  WHERE up.id != p_admin_id;

  GET DIAGNOSTICS v_user_count = ROW_COUNT;

  -- Log the admin action
  INSERT INTO admin_activity_logs (admin_id, action_type, action_description, metadata)
  VALUES (
    p_admin_id,
    'broadcast_notification',
    'Sent broadcast notification to all users',
    jsonb_build_object(
      'title', p_title,
      'message', p_message,
      'notification_type', v_valid_type,
      'redirect_url', p_redirect_url,
      'users_notified', v_user_count
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_count', v_user_count,
    'notification_type', v_valid_type
  );
END;
$$;
