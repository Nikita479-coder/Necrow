/*
  # Update Admin Enroll Exclusive Affiliate to Support Copy Profit Rates

  ## Overview
  Updates the admin_enroll_exclusive_affiliate function to accept and store
  custom copy_profit_rates for VIP affiliates.

  ## Changes
  - Add p_copy_profit_rates parameter (default: 10%, 5%, 4%, 3%, 2% for levels 1-5)
  - Store copy_profit_rates in exclusive_affiliates table
  - Update notification message to include copy profit information
  - Return copy_profit_rates in response

  ## Security
  - Uses SECURITY DEFINER with restricted search_path
  - Admin authorization check
*/

-- Need to drop and recreate since we're adding a parameter
DROP FUNCTION IF EXISTS admin_enroll_exclusive_affiliate(uuid, text, jsonb, jsonb);

CREATE OR REPLACE FUNCTION admin_enroll_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1}'::jsonb,
  p_fee_rates jsonb DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10}'::jsonb,
  p_copy_profit_rates jsonb DEFAULT '{"level_1": 10, "level_2": 5, "level_3": 4, "level_4": 3, "level_5": 2}'::jsonb
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
    copy_profit_rates,
    is_active
  ) VALUES (
    v_user_id,
    p_admin_id,
    p_deposit_rates,
    p_fee_rates,
    p_copy_profit_rates,
    true
  )
  ON CONFLICT (user_id) DO UPDATE SET
    deposit_commission_rates = EXCLUDED.deposit_commission_rates,
    fee_share_rates = EXCLUDED.fee_share_rates,
    copy_profit_rates = EXCLUDED.copy_profit_rates,
    is_active = true,
    updated_at = now();
  
  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;
  
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_user_id,
    'system',
    'VIP Affiliate Program Activated',
    'Congratulations! You have been enrolled in the exclusive VIP Affiliate Program. You now earn deposit commissions, trading fee revenue share, and copy trading profit commissions from your 5-level network.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', p_user_email,
    'deposit_rates', p_deposit_rates,
    'fee_rates', p_fee_rates,
    'copy_profit_rates', p_copy_profit_rates
  );
END;
$$;

-- Also create a function to update rates for existing affiliates
CREATE OR REPLACE FUNCTION admin_update_exclusive_affiliate_rates(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT NULL,
  p_fee_rates jsonb DEFAULT NULL,
  p_copy_profit_rates jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_affiliate exclusive_affiliates;
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
  
  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = v_user_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is not an exclusive affiliate');
  END IF;
  
  UPDATE exclusive_affiliates
  SET 
    deposit_commission_rates = COALESCE(p_deposit_rates, deposit_commission_rates),
    fee_share_rates = COALESCE(p_fee_rates, fee_share_rates),
    copy_profit_rates = COALESCE(p_copy_profit_rates, copy_profit_rates),
    updated_at = now()
  WHERE user_id = v_user_id;
  
  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', p_user_email,
    'deposit_rates', v_affiliate.deposit_commission_rates,
    'fee_rates', v_affiliate.fee_share_rates,
    'copy_profit_rates', v_affiliate.copy_profit_rates
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_enroll_exclusive_affiliate(uuid, text, jsonb, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_exclusive_affiliate_rates(uuid, text, jsonb, jsonb, jsonb) TO authenticated;
