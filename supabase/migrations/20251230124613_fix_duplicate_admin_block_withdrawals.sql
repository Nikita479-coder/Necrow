/*
  # Fix Duplicate admin_block_withdrawals Functions

  1. Problem
    - Multiple versions of the function exist with different column names

  2. Fix
    - Drop all versions and recreate with correct column names
*/

-- Drop all versions
DROP FUNCTION IF EXISTS admin_block_withdrawals(uuid, uuid, text);

-- Recreate with correct column names
CREATE OR REPLACE FUNCTION admin_block_withdrawals(
  p_admin_id uuid,
  p_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
  v_admin_username text;
BEGIN
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  SELECT username INTO v_username FROM user_profiles WHERE id = p_user_id;
  SELECT username INTO v_admin_username FROM user_profiles WHERE id = p_admin_id;

  UPDATE user_profiles
  SET 
    withdrawal_blocked = true,
    withdrawal_block_reason = p_reason,
    withdrawal_blocked_by = p_admin_id,
    withdrawal_blocked_at = now()
  WHERE id = p_user_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'withdrawal_blocked',
    'Withdrawals Temporarily Blocked',
    'Your withdrawals have been temporarily blocked. Reason: ' || p_reason || '. Please contact support for more information.',
    false
  );

  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    p_admin_id,
    'block_withdrawals',
    p_user_id,
    jsonb_build_object(
      'reason', p_reason,
      'username', v_username,
      'admin_username', v_admin_username
    ),
    NULL
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Withdrawals blocked for user'
  );
END;
$$;
