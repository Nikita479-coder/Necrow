/*
  # Update get_exclusive_affiliate_stats to Include Copy Profit Data

  ## Overview
  Updates the get_exclusive_affiliate_stats function to include:
  - copy_profit_rates in the rates section
  - copy_profit_earned in the balance section

  ## Changes
  - Add `copy_profit_rates` to the response alongside deposit_rates and fee_rates
  - Add `copy_profit` to the balance breakdown

  ## Security
  - Uses SECURITY DEFINER with restricted search_path
*/

CREATE OR REPLACE FUNCTION get_exclusive_affiliate_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate exclusive_affiliates;
  v_balance exclusive_affiliate_balances;
  v_network exclusive_affiliate_network_stats;
  v_recent_commissions jsonb;
  v_referral_code text;
BEGIN
  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = p_user_id AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('enrolled', false);
  END IF;
  
  SELECT * INTO v_balance
  FROM exclusive_affiliate_balances
  WHERE user_id = p_user_id;
  
  SELECT * INTO v_network
  FROM exclusive_affiliate_network_stats
  WHERE affiliate_id = p_user_id;
  
  SELECT referral_code INTO v_referral_code
  FROM user_profiles
  WHERE id = p_user_id;
  
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id,
      'tier_level', tier_level,
      'commission_type', commission_type,
      'source_amount', source_amount,
      'commission_rate', commission_rate,
      'commission_amount', commission_amount,
      'created_at', created_at
    ) ORDER BY created_at DESC
  ) INTO v_recent_commissions
  FROM (
    SELECT * FROM exclusive_affiliate_commissions
    WHERE affiliate_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 20
  ) recent;
  
  RETURN jsonb_build_object(
    'enrolled', true,
    'referral_code', v_referral_code,
    'deposit_rates', v_affiliate.deposit_commission_rates,
    'fee_rates', v_affiliate.fee_share_rates,
    'copy_profit_rates', COALESCE(v_affiliate.copy_profit_rates, '{"level_1": 10, "level_2": 5, "level_3": 4, "level_4": 3, "level_5": 2}'::jsonb),
    'balance', jsonb_build_object(
      'available', COALESCE(v_balance.available_balance, 0),
      'pending', COALESCE(v_balance.pending_balance, 0),
      'total_earned', COALESCE(v_balance.total_earned, 0),
      'total_withdrawn', COALESCE(v_balance.total_withdrawn, 0),
      'deposit_commissions', COALESCE(v_balance.deposit_commissions_earned, 0),
      'fee_share', COALESCE(v_balance.fee_share_earned, 0),
      'copy_profit', COALESCE(v_balance.copy_profit_earned, 0)
    ),
    'network', jsonb_build_object(
      'level_1_count', COALESCE(v_network.level_1_count, 0),
      'level_2_count', COALESCE(v_network.level_2_count, 0),
      'level_3_count', COALESCE(v_network.level_3_count, 0),
      'level_4_count', COALESCE(v_network.level_4_count, 0),
      'level_5_count', COALESCE(v_network.level_5_count, 0),
      'level_1_earnings', COALESCE(v_network.level_1_earnings, 0),
      'level_2_earnings', COALESCE(v_network.level_2_earnings, 0),
      'level_3_earnings', COALESCE(v_network.level_3_earnings, 0),
      'level_4_earnings', COALESCE(v_network.level_4_earnings, 0),
      'level_5_earnings', COALESCE(v_network.level_5_earnings, 0),
      'this_month', COALESCE(v_network.this_month_earnings, 0)
    ),
    'recent_commissions', COALESCE(v_recent_commissions, '[]'::jsonb)
  );
END;
$$;
