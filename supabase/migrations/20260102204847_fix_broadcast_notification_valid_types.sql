/*
  # Fix Broadcast Notification Types

  1. Changes
    - Add 'broadcast' and 'reward' to the notifications type check constraint
    - Update the broadcast function to validate types properly

  2. Security
    - Function validates admin status before sending
*/

-- Drop and recreate the constraint with new types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (ARRAY[
    'referral_payout'::text,
    'trade_executed'::text,
    'kyc_update'::text,
    'account_update'::text,
    'system'::text,
    'copy_trade'::text,
    'position_closed'::text,
    'position_sl_hit'::text,
    'position_tp_hit'::text,
    'position_liquidated'::text,
    'vip_downgrade'::text,
    'vip_upgrade'::text,
    'shark_card_application'::text,
    'withdrawal_completed'::text,
    'withdrawal_rejected'::text,
    'bonus'::text,
    'affiliate_payout'::text,
    'pending_copy_trade'::text,
    'deposit_completed'::text,
    'deposit_failed'::text,
    'broadcast'::text,
    'reward'::text,
    'promotion'::text
  ])
);

-- Update the broadcast function to use valid type
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
  -- Check if user is admin
  SELECT (is_admin = true OR EXISTS (
    SELECT 1 FROM admin_staff WHERE user_id = p_admin_id AND is_super_admin = true
  ))
  INTO v_is_admin
  FROM user_profiles
  WHERE id = p_admin_id;

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
  INSERT INTO admin_action_logs (admin_id, action, target_type, details)
  VALUES (
    p_admin_id,
    'broadcast_notification',
    'all_users',
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
