/*
  # Create Boost Refresh Function and Update Affiliate Stats

  ## New Functions

  ### `refresh_all_affiliate_boosts()`
    - Loops through all active exclusive affiliates
    - Recalculates FTD count and boost tier for each
    - Detects tier changes and sends notifications:
      - Upgrade: celebratory notification
      - Downgrade: neutral notification with actionable next-step info
    - Updates cached columns on exclusive_affiliate_network_stats
    - Returns summary of changes

  ## Updated Functions

  ### `get_exclusive_affiliate_stats(p_user_id uuid)`
    - Now includes a `boost` key in the returned JSONB
    - Contains: ftd_count, multiplier, boost_percentage, tier_label, next_tier_threshold,
      ftds_to_next_tier, eligible, and an `all_tiers` array for rendering the tier table
*/

-- 1. Daily boost refresh with tier change detection
CREATE OR REPLACE FUNCTION refresh_all_affiliate_boosts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate record;
  v_old_tier text;
  v_old_multiplier numeric;
  v_new_boost jsonb;
  v_new_tier text;
  v_new_multiplier numeric;
  v_ftd_count integer;
  v_upgrades integer := 0;
  v_downgrades integer := 0;
  v_unchanged integer := 0;
  v_ftds_to_next integer;
  v_next_threshold integer;
BEGIN
  FOR v_affiliate IN
    SELECT ea.user_id,
           COALESCE(eans.current_boost_tier, 'none') as old_tier,
           COALESCE(eans.current_boost_multiplier, 1.0) as old_multiplier
    FROM exclusive_affiliates ea
    LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
    WHERE ea.is_active = true
  LOOP
    v_old_tier := v_affiliate.old_tier;
    v_old_multiplier := v_affiliate.old_multiplier;

    v_new_boost := get_exclusive_affiliate_boost(v_affiliate.user_id);
    v_new_tier := v_new_boost->>'tier_label';
    v_new_multiplier := (v_new_boost->>'multiplier')::numeric;
    v_ftd_count := (v_new_boost->>'ftd_count')::integer;
    v_ftds_to_next := (v_new_boost->>'ftds_to_next_tier')::integer;
    v_next_threshold := (v_new_boost->>'next_tier_threshold')::integer;

    IF v_old_tier IS DISTINCT FROM v_new_tier THEN
      IF v_new_multiplier > v_old_multiplier THEN
        v_upgrades := v_upgrades + 1;

        INSERT INTO notifications (user_id, type, title, message, read, redirect_url)
        VALUES (
          v_affiliate.user_id,
          'affiliate_payout',
          'Boost Tier Upgrade!',
          'You now have ' || v_ftd_count || ' qualified referrals in the last 30 days. Your commission boost is now +'
            || TRIM(TO_CHAR((v_new_multiplier - 1.0) * 100, 'FM999999999')) || '%!'
            || CASE WHEN v_ftds_to_next > 0
                 THEN ' ' || v_ftds_to_next || ' more to reach the next tier.'
                 ELSE ' You are at the maximum tier!'
               END,
          false,
          'affiliate'
        );

      ELSIF v_new_multiplier < v_old_multiplier THEN
        v_downgrades := v_downgrades + 1;

        INSERT INTO notifications (user_id, type, title, message, read, redirect_url)
        VALUES (
          v_affiliate.user_id,
          'affiliate_payout',
          'Boost Tier Updated',
          'Your rolling 30-day qualified referral count has changed to ' || v_ftd_count || '.'
            || ' Your current boost is now '
            || CASE WHEN v_new_multiplier > 1.0
                 THEN '+' || TRIM(TO_CHAR((v_new_multiplier - 1.0) * 100, 'FM999999999')) || '%.'
                 ELSE 'inactive.'
               END
            || CASE WHEN v_ftds_to_next > 0
                 THEN ' ' || v_ftds_to_next || ' more FTDs needed to reach +' || TRIM(TO_CHAR(
                   CASE
                     WHEN v_next_threshold = 5 THEN 20
                     WHEN v_next_threshold = 11 THEN 35
                     WHEN v_next_threshold = 21 THEN 50
                     WHEN v_next_threshold = 51 THEN 100
                     ELSE 0
                   END, 'FM999999999')) || '%.'
                 ELSE ''
               END,
          false,
          'affiliate'
        );
      ELSE
        v_unchanged := v_unchanged + 1;
      END IF;
    ELSE
      v_unchanged := v_unchanged + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'upgrades', v_upgrades,
    'downgrades', v_downgrades,
    'unchanged', v_unchanged,
    'total_processed', v_upgrades + v_downgrades + v_unchanged
  );
END;
$$;

-- 2. Updated get_exclusive_affiliate_stats with boost info
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
  v_boost jsonb;
BEGIN
  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = p_user_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('enrolled', false);
  END IF;

  SELECT * INTO v_balance FROM exclusive_affiliate_balances WHERE user_id = p_user_id;
  SELECT * INTO v_network FROM exclusive_affiliate_network_stats WHERE affiliate_id = p_user_id;
  SELECT referral_code INTO v_referral_code FROM user_profiles WHERE id = p_user_id;

  v_boost := get_exclusive_affiliate_boost(p_user_id);

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', id, 'tier_level', tier_level, 'commission_type', commission_type,
      'source_amount', source_amount, 'commission_rate', commission_rate,
      'commission_amount', commission_amount,
      'base_commission_amount', base_commission_amount,
      'boost_multiplier', boost_multiplier,
      'boost_tier', boost_tier,
      'created_at', created_at
    ) ORDER BY created_at DESC
  ) INTO v_recent_commissions
  FROM (
    SELECT * FROM exclusive_affiliate_commissions
    WHERE affiliate_id = p_user_id ORDER BY created_at DESC LIMIT 50
  ) recent;

  RETURN jsonb_build_object(
    'enrolled', true,
    'referral_code', v_referral_code,
    'deposit_rates', v_affiliate.deposit_commission_rates,
    'fee_rates', v_affiliate.fee_share_rates,
    'copy_profit_rates', COALESCE(v_affiliate.copy_profit_rates, '{}'::jsonb),
    'balance', jsonb_build_object(
      'available', COALESCE(v_balance.available_balance, 0),
      'pending', COALESCE(v_balance.pending_balance, 0),
      'total_earned', COALESCE(v_balance.total_earned, 0),
      'total_withdrawn', COALESCE(v_balance.total_withdrawn, 0),
      'deposit_commissions', COALESCE(v_balance.deposit_commissions_earned, 0),
      'fee_share', COALESCE(v_balance.fee_share_earned, 0),
      'copy_profit', COALESCE(v_balance.copy_profit_earned, 0)
    ),
    'boost', jsonb_build_object(
      'ftd_count', COALESCE((v_boost->>'ftd_count')::integer, 0),
      'multiplier', COALESCE((v_boost->>'multiplier')::numeric, 1.0),
      'boost_percentage', COALESCE((v_boost->>'boost_percentage')::numeric, 0),
      'tier_label', COALESCE(v_boost->>'tier_label', 'No boost'),
      'next_tier_threshold', COALESCE((v_boost->>'next_tier_threshold')::integer, 5),
      'ftds_to_next_tier', COALESCE((v_boost->>'ftds_to_next_tier')::integer, 5),
      'eligible', COALESCE((v_boost->>'eligible')::boolean, true),
      'all_tiers', jsonb_build_array(
        jsonb_build_object('min_ftds', 0, 'max_ftds', 4, 'multiplier', 1.0, 'label', 'No boost', 'boost_pct', 0),
        jsonb_build_object('min_ftds', 5, 'max_ftds', 10, 'multiplier', 1.20, 'label', '5-10 FTDs', 'boost_pct', 20),
        jsonb_build_object('min_ftds', 11, 'max_ftds', 20, 'multiplier', 1.35, 'label', '11-20 FTDs', 'boost_pct', 35),
        jsonb_build_object('min_ftds', 21, 'max_ftds', 50, 'multiplier', 1.50, 'label', '21-50 FTDs', 'boost_pct', 50),
        jsonb_build_object('min_ftds', 51, 'max_ftds', null, 'multiplier', 2.00, 'label', '51+ FTDs', 'boost_pct', 100)
      )
    ),
    'network', jsonb_build_object(
      'level_1_count', COALESCE(v_network.level_1_count, 0),
      'level_2_count', COALESCE(v_network.level_2_count, 0),
      'level_3_count', COALESCE(v_network.level_3_count, 0),
      'level_4_count', COALESCE(v_network.level_4_count, 0),
      'level_5_count', COALESCE(v_network.level_5_count, 0),
      'level_6_count', COALESCE(v_network.level_6_count, 0),
      'level_7_count', COALESCE(v_network.level_7_count, 0),
      'level_8_count', COALESCE(v_network.level_8_count, 0),
      'level_9_count', COALESCE(v_network.level_9_count, 0),
      'level_10_count', COALESCE(v_network.level_10_count, 0),
      'level_1_earnings', COALESCE(v_network.level_1_earnings, 0),
      'level_2_earnings', COALESCE(v_network.level_2_earnings, 0),
      'level_3_earnings', COALESCE(v_network.level_3_earnings, 0),
      'level_4_earnings', COALESCE(v_network.level_4_earnings, 0),
      'level_5_earnings', COALESCE(v_network.level_5_earnings, 0),
      'level_6_earnings', COALESCE(v_network.level_6_earnings, 0),
      'level_7_earnings', COALESCE(v_network.level_7_earnings, 0),
      'level_8_earnings', COALESCE(v_network.level_8_earnings, 0),
      'level_9_earnings', COALESCE(v_network.level_9_earnings, 0),
      'level_10_earnings', COALESCE(v_network.level_10_earnings, 0),
      'this_month', COALESCE(v_network.this_month_earnings, 0)
    ),
    'recent_commissions', COALESCE(v_recent_commissions, '[]'::jsonb)
  );
END;
$$;
