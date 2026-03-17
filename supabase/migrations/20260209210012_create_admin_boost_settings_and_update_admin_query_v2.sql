/*
  # Admin Boost Settings and Updated Admin Query (v2)

  ## New Functions

  ### `admin_update_affiliate_boost_settings`
    - Allows admins to toggle boost eligibility and set override multipliers per affiliate
    - Logs changes to admin_activity_logs
    - Notifies the affiliate of changes

  ## Updated Functions

  ### `admin_get_exclusive_affiliates`
    - Dropped and recreated to add boost columns
    - Now returns: is_boost_eligible, boost_override_multiplier, ftd_count_30d, current_boost_tier, current_boost_multiplier
*/

-- 1. Admin function to update boost settings for an affiliate
CREATE OR REPLACE FUNCTION admin_update_affiliate_boost_settings(
  p_admin_id uuid,
  p_affiliate_user_id uuid,
  p_is_boost_eligible boolean,
  p_boost_override_multiplier numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate exclusive_affiliates;
  v_old_eligible boolean;
  v_old_override numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Affiliate not found');
  END IF;

  v_old_eligible := COALESCE(v_affiliate.is_boost_eligible, true);
  v_old_override := v_affiliate.boost_override_multiplier;

  UPDATE exclusive_affiliates
  SET
    is_boost_eligible = p_is_boost_eligible,
    boost_override_multiplier = p_boost_override_multiplier,
    updated_at = now()
  WHERE user_id = p_affiliate_user_id;

  INSERT INTO admin_activity_logs (
    admin_id, action_type, target_user_id, details
  ) VALUES (
    p_admin_id,
    'update_affiliate_boost',
    p_affiliate_user_id,
    jsonb_build_object(
      'old_eligible', v_old_eligible,
      'new_eligible', p_is_boost_eligible,
      'old_override', v_old_override,
      'new_override', p_boost_override_multiplier
    )
  );

  IF v_old_eligible = true AND p_is_boost_eligible = false THEN
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      p_affiliate_user_id,
      'account_update',
      'Recruitment Boost Updated',
      'The recruitment boost is currently not active for your account. Your base commission rates remain unchanged.',
      false
    );
  ELSIF v_old_eligible = false AND p_is_boost_eligible = true THEN
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      p_affiliate_user_id,
      'account_update',
      'Recruitment Boost Activated',
      'The recruitment boost has been activated for your account. Refer qualified traders to earn boosted commissions!',
      false
    );
  END IF;

  PERFORM get_exclusive_affiliate_boost(p_affiliate_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'is_boost_eligible', p_is_boost_eligible,
    'boost_override_multiplier', p_boost_override_multiplier
  );
END;
$$;

-- 2. Drop old version and recreate with new return type
DROP FUNCTION IF EXISTS admin_get_exclusive_affiliates();

CREATE OR REPLACE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE(
  affiliate_id uuid,
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  deposit_commission_rates jsonb,
  fee_share_rates jsonb,
  copy_profit_rates jsonb,
  is_active boolean,
  enrolled_at timestamptz,
  enrolled_by_email text,
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  deposit_commissions_earned numeric,
  fee_share_earned numeric,
  copy_profit_earned numeric,
  network_size bigint,
  this_month_earnings numeric,
  is_boost_eligible boolean,
  boost_override_multiplier numeric,
  ftd_count_30d integer,
  current_boost_tier text,
  current_boost_multiplier numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    ea.id as affiliate_id,
    ea.user_id,
    get_user_email(ea.user_id) as email,
    up.full_name,
    up.username,
    up.referral_code,
    ea.deposit_commission_rates,
    ea.fee_share_rates,
    COALESCE(ea.copy_profit_rates, '{}'::jsonb) as copy_profit_rates,
    ea.is_active,
    ea.created_at as enrolled_at,
    get_user_email(ea.enrolled_by) as enrolled_by_email,
    COALESCE(eab.available_balance, 0) as available_balance,
    COALESCE(eab.pending_balance, 0) as pending_balance,
    COALESCE(eab.total_earned, 0) as total_earned,
    COALESCE(eab.total_withdrawn, 0) as total_withdrawn,
    COALESCE(eab.deposit_commissions_earned, 0) as deposit_commissions_earned,
    COALESCE(eab.fee_share_earned, 0) as fee_share_earned,
    COALESCE(eab.copy_profit_earned, 0) as copy_profit_earned,
    (
      COALESCE(eans.level_1_count, 0)::bigint + COALESCE(eans.level_2_count, 0)::bigint +
      COALESCE(eans.level_3_count, 0)::bigint + COALESCE(eans.level_4_count, 0)::bigint +
      COALESCE(eans.level_5_count, 0)::bigint + COALESCE(eans.level_6_count, 0)::bigint +
      COALESCE(eans.level_7_count, 0)::bigint + COALESCE(eans.level_8_count, 0)::bigint +
      COALESCE(eans.level_9_count, 0)::bigint + COALESCE(eans.level_10_count, 0)::bigint
    ) as network_size,
    COALESCE(eans.this_month_earnings, 0) as this_month_earnings,
    COALESCE(ea.is_boost_eligible, true) as is_boost_eligible,
    ea.boost_override_multiplier,
    COALESCE(eans.ftd_count_30d, 0) as ftd_count_30d,
    COALESCE(eans.current_boost_tier, 'none') as current_boost_tier,
    COALESCE(eans.current_boost_multiplier, 1.0) as current_boost_multiplier
  FROM exclusive_affiliates ea
  JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN exclusive_affiliate_balances eab ON eab.user_id = ea.user_id
  LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
  ORDER BY ea.created_at DESC;
END;
$$;
