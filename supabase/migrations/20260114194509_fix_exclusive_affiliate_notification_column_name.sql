/*
  # Fix Exclusive Affiliate Notification Column Name

  ## Description
  The admin_enroll_exclusive_affiliate function was using "is_read" column
  which doesn't exist. The correct column name is "read".

  ## Changes
  - Updates admin_enroll_exclusive_affiliate to use "read" instead of "is_read"

  ## Security
  - No security changes
  - Existing RLS policies continue to apply
*/

-- Fix the admin_enroll_exclusive_affiliate function to use the correct column name
CREATE OR REPLACE FUNCTION admin_enroll_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}',
  p_fee_rates jsonb DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}',
  p_copy_profit_rates jsonb DEFAULT '{"level_1": 10, "level_2": 5, "level_3": 4, "level_4": 3, "level_5": 2, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  SELECT id INTO v_target_user_id
  FROM auth.users
  WHERE email = p_user_email;

  IF v_target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF EXISTS (SELECT 1 FROM exclusive_affiliates WHERE user_id = v_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is already enrolled');
  END IF;

  INSERT INTO exclusive_affiliates (
    user_id,
    enrolled_by,
    deposit_commission_rates,
    fee_share_rates,
    copy_profit_rates,
    is_active
  ) VALUES (
    v_target_user_id,
    p_admin_id,
    p_deposit_rates,
    p_fee_rates,
    p_copy_profit_rates,
    true
  );

  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_target_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_target_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;

  INSERT INTO admin_activity_logs (admin_id, action_type, target_user_id, action_description, metadata)
  VALUES (
    p_admin_id,
    'enroll_exclusive_affiliate',
    v_target_user_id,
    'Enrolled user in exclusive affiliate program',
    jsonb_build_object(
      'deposit_rates', p_deposit_rates,
      'fee_rates', p_fee_rates,
      'copy_profit_rates', p_copy_profit_rates
    )
  );

  -- Fixed: Use "read" instead of "is_read"
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_target_user_id,
    'system',
    'Welcome to Exclusive Affiliate Program!',
    'You have been enrolled in our exclusive multi-level affiliate program with up to 10 levels of commissions. Start sharing your referral link to earn!',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_target_user_id
  );
END;
$$;
