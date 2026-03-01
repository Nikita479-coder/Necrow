/*
  # Create Withdrawal Block System for CRM
  
  1. New Columns
    - Add withdrawal_blocked to user_profiles
    - Add withdrawal_block_reason to user_profiles
    - Add withdrawal_blocked_by (admin who blocked)
    - Add withdrawal_blocked_at timestamp
  
  2. New Functions
    - `admin_block_withdrawals` - Block withdrawals for a user
    - `admin_unblock_withdrawals` - Unblock withdrawals for a user
    - `check_withdrawal_allowed` - Check if user can withdraw
  
  3. Security
    - Only admins can block/unblock withdrawals
    - All actions are logged
    - Users are notified when blocked/unblocked
*/

-- Add withdrawal block columns to user_profiles
ALTER TABLE user_profiles 
  ADD COLUMN IF NOT EXISTS withdrawal_blocked boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS withdrawal_block_reason text,
  ADD COLUMN IF NOT EXISTS withdrawal_blocked_by uuid REFERENCES user_profiles(id),
  ADD COLUMN IF NOT EXISTS withdrawal_blocked_at timestamptz;

-- Create index for quick lookup
CREATE INDEX IF NOT EXISTS idx_user_profiles_withdrawal_blocked 
  ON user_profiles(withdrawal_blocked) WHERE withdrawal_blocked = true;

-- Function to block withdrawals for a user
CREATE OR REPLACE FUNCTION admin_block_withdrawals(
  p_user_id uuid,
  p_reason text,
  p_admin_id uuid DEFAULT auth.uid()
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
  -- Check if caller is admin
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get usernames for logging
  SELECT username INTO v_username FROM user_profiles WHERE id = p_user_id;
  SELECT username INTO v_admin_username FROM user_profiles WHERE id = p_admin_id;

  -- Block withdrawals
  UPDATE user_profiles
  SET 
    withdrawal_blocked = true,
    withdrawal_block_reason = p_reason,
    withdrawal_blocked_by = p_admin_id,
    withdrawal_blocked_at = now()
  WHERE id = p_user_id;

  -- Create notification for user
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    p_user_id,
    'withdrawal_blocked',
    'Withdrawals Temporarily Blocked',
    'Your withdrawals have been temporarily blocked. Reason: ' || p_reason || '. Please contact support for more information.',
    false
  );

  -- Log the action
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

-- Function to unblock withdrawals for a user
CREATE OR REPLACE FUNCTION admin_unblock_withdrawals(
  p_user_id uuid,
  p_admin_id uuid DEFAULT auth.uid()
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
  -- Check if caller is admin
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  -- Get usernames for logging
  SELECT username INTO v_username FROM user_profiles WHERE id = p_user_id;
  SELECT username INTO v_admin_username FROM user_profiles WHERE id = p_admin_id;

  -- Unblock withdrawals
  UPDATE user_profiles
  SET 
    withdrawal_blocked = false,
    withdrawal_block_reason = NULL,
    withdrawal_blocked_by = NULL,
    withdrawal_blocked_at = NULL
  WHERE id = p_user_id;

  -- Create notification for user
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    p_user_id,
    'withdrawal_unblocked',
    'Withdrawals Enabled',
    'Your withdrawals have been enabled. You can now withdraw funds.',
    false
  );

  -- Log the action
  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    p_admin_id,
    'unblock_withdrawals',
    p_user_id,
    jsonb_build_object(
      'username', v_username,
      'admin_username', v_admin_username
    ),
    NULL
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Withdrawals unblocked for user'
  );
END;
$$;

-- Function to check if withdrawals are allowed
CREATE OR REPLACE FUNCTION check_withdrawal_allowed(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean;
  v_reason text;
  v_blocked_at timestamptz;
BEGIN
  SELECT withdrawal_blocked, withdrawal_block_reason, withdrawal_blocked_at
  INTO v_blocked, v_reason, v_blocked_at
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_blocked THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', COALESCE(v_reason, 'Withdrawals are temporarily blocked'),
      'blocked_at', v_blocked_at
    );
  ELSE
    RETURN jsonb_build_object(
      'allowed', true
    );
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION admin_block_withdrawals(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_unblock_withdrawals(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION check_withdrawal_allowed(uuid) TO authenticated;