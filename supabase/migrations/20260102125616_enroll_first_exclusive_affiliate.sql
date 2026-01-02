/*
  # Enroll First Exclusive Affiliate

  ## Summary
  Enrolls sulaiman300495@gmail.com in the exclusive affiliate program with:
  - Deposit commissions: Level 1-5% | Level 2-4% | Level 3-3% | Level 4-2% | Level 5-1%
  - Fee revenue share: Level 1-50% | Level 2-40% | Level 3-30% | Level 4-20% | Level 5-10%

  ## Security
  - Only affects the specified user
  - Creates initial balance and network stats records
*/

DO $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'sulaiman300495@gmail.com';
  
  IF v_user_id IS NULL THEN
    RAISE NOTICE 'User sulaiman300495@gmail.com not found - will be enrolled when they sign up';
    RETURN;
  END IF;
  
  INSERT INTO exclusive_affiliates (
    user_id,
    deposit_commission_rates,
    fee_share_rates,
    is_active
  ) VALUES (
    v_user_id,
    '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1}'::jsonb,
    '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10}'::jsonb,
    true
  )
  ON CONFLICT (user_id) DO UPDATE SET
    deposit_commission_rates = EXCLUDED.deposit_commission_rates,
    fee_share_rates = EXCLUDED.fee_share_rates,
    is_active = true,
    updated_at = now();
  
  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;
  
  RAISE NOTICE 'Successfully enrolled user % in exclusive affiliate program', v_user_id;
END;
$$;

-- Also create an admin function to enroll users
CREATE OR REPLACE FUNCTION admin_enroll_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1}'::jsonb,
  p_fee_rates jsonb DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_user_email;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
  
  INSERT INTO exclusive_affiliates (
    user_id,
    enrolled_by,
    deposit_commission_rates,
    fee_share_rates,
    is_active
  ) VALUES (
    v_user_id,
    p_admin_id,
    p_deposit_rates,
    p_fee_rates,
    true
  )
  ON CONFLICT (user_id) DO UPDATE SET
    deposit_commission_rates = EXCLUDED.deposit_commission_rates,
    fee_share_rates = EXCLUDED.fee_share_rates,
    is_active = true,
    updated_at = now();
  
  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;
  
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    v_user_id,
    'system',
    'VIP Affiliate Program Activated',
    'Congratulations! You have been enrolled in the exclusive VIP Affiliate Program. You now earn deposit commissions (5-1%) and trading fee revenue share (50-10%) from your 5-level network.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', p_user_email,
    'deposit_rates', p_deposit_rates,
    'fee_rates', p_fee_rates
  );
END;
$$;

-- Function to remove user from exclusive program
CREATE OR REPLACE FUNCTION admin_remove_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_user_email;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
  
  UPDATE exclusive_affiliates
  SET is_active = false, updated_at = now()
  WHERE user_id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'message', 'User removed from exclusive affiliate program'
  );
END;
$$;
