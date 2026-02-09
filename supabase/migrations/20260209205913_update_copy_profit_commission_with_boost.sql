/*
  # Update Copy Profit Commission Distribution with Recruitment Boost

  ## Summary
  Updates `distribute_exclusive_copy_profit_commission` to apply the rolling 30-day
  recruitment boost. Identical boost logic as deposit commissions.

  ## Changes
  - Calls `get_exclusive_affiliate_boost()` for each affiliate
  - Calculates base commission, applies boost multiplier
  - Stores `base_commission_amount`, `boost_multiplier`, `boost_tier` per record
  - Notification messages mention boost when active
*/

CREATE OR REPLACE FUNCTION distribute_exclusive_copy_profit_commission(
  p_copier_id uuid,
  p_profit_amount numeric,
  p_reference_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_upline record;
  v_base_commission numeric;
  v_commission_amount numeric;
  v_total_distributed numeric := 0;
  v_distributions jsonb := '[]'::jsonb;
  v_boost jsonb;
  v_boost_multiplier numeric;
  v_boost_tier text;
BEGIN
  IF p_profit_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No commission distributed - no profit',
      'total_distributed', 0,
      'distributions', '[]'::jsonb
    );
  END IF;

  FOR v_upline IN SELECT * FROM get_exclusive_upline_chain(p_copier_id) LOOP
    IF v_upline.copy_profit_rate > 0 THEN
      v_base_commission := ROUND((p_profit_amount * v_upline.copy_profit_rate / 100)::numeric, 2);

      IF v_base_commission >= 0.01 THEN
        v_boost := get_exclusive_affiliate_boost(v_upline.affiliate_id);
        v_boost_multiplier := COALESCE((v_boost->>'multiplier')::numeric, 1.0);
        v_boost_tier := COALESCE(v_boost->>'tier_label', 'No boost');

        v_commission_amount := ROUND(v_base_commission * v_boost_multiplier, 2);

        INSERT INTO exclusive_affiliate_commissions (
          affiliate_id, source_user_id, tier_level, commission_type,
          source_amount, commission_rate, commission_amount,
          base_commission_amount, boost_multiplier, boost_tier,
          reference_id, reference_type, status
        ) VALUES (
          v_upline.affiliate_id, p_copier_id, v_upline.tier_level, 'copy_profit',
          p_profit_amount, v_upline.copy_profit_rate, v_commission_amount,
          v_base_commission, v_boost_multiplier, v_boost_tier,
          p_reference_id, 'copy_trade', 'credited'
        );

        INSERT INTO exclusive_affiliate_balances (
          user_id, available_balance, total_earned, copy_profit_earned
        )
        VALUES (
          v_upline.affiliate_id, v_commission_amount, v_commission_amount, v_commission_amount
        )
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = exclusive_affiliate_balances.available_balance + v_commission_amount,
          total_earned = exclusive_affiliate_balances.total_earned + v_commission_amount,
          copy_profit_earned = exclusive_affiliate_balances.copy_profit_earned + v_commission_amount,
          updated_at = now();

        INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
        VALUES (v_upline.affiliate_id)
        ON CONFLICT (affiliate_id) DO NOTHING;

        UPDATE exclusive_affiliate_network_stats
        SET
          level_1_earnings = CASE WHEN v_upline.tier_level = 1 THEN level_1_earnings + v_commission_amount ELSE level_1_earnings END,
          level_2_earnings = CASE WHEN v_upline.tier_level = 2 THEN level_2_earnings + v_commission_amount ELSE level_2_earnings END,
          level_3_earnings = CASE WHEN v_upline.tier_level = 3 THEN level_3_earnings + v_commission_amount ELSE level_3_earnings END,
          level_4_earnings = CASE WHEN v_upline.tier_level = 4 THEN level_4_earnings + v_commission_amount ELSE level_4_earnings END,
          level_5_earnings = CASE WHEN v_upline.tier_level = 5 THEN level_5_earnings + v_commission_amount ELSE level_5_earnings END,
          level_6_earnings = CASE WHEN v_upline.tier_level = 6 THEN level_6_earnings + v_commission_amount ELSE level_6_earnings END,
          level_7_earnings = CASE WHEN v_upline.tier_level = 7 THEN level_7_earnings + v_commission_amount ELSE level_7_earnings END,
          level_8_earnings = CASE WHEN v_upline.tier_level = 8 THEN level_8_earnings + v_commission_amount ELSE level_8_earnings END,
          level_9_earnings = CASE WHEN v_upline.tier_level = 9 THEN level_9_earnings + v_commission_amount ELSE level_9_earnings END,
          level_10_earnings = CASE WHEN v_upline.tier_level = 10 THEN level_10_earnings + v_commission_amount ELSE level_10_earnings END,
          this_month_earnings = this_month_earnings + v_commission_amount,
          updated_at = now()
        WHERE affiliate_id = v_upline.affiliate_id;

        INSERT INTO notifications (user_id, type, title, message, read, data)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Copy Trading Profit Commission',
          'You earned $' || TRIM(TO_CHAR(v_commission_amount, 'FM999999999.00'))
            || ' (' || TRIM(TO_CHAR(v_upline.copy_profit_rate, 'FM999999999.##'))
            || '% of $' || TRIM(TO_CHAR(p_profit_amount, 'FM999999999.00')) || ' profit'
            || CASE WHEN v_boost_multiplier > 1.0
                 THEN ' + ' || TRIM(TO_CHAR((v_boost_multiplier - 1.0) * 100, 'FM999999999')) || '% boost'
                 ELSE ''
               END
            || ') from a copy trade in your network (Level ' || v_upline.tier_level || ').',
          false,
          jsonb_build_object(
            'commission_type', 'copy_profit',
            'tier_level', v_upline.tier_level,
            'profit_amount', p_profit_amount,
            'commission_rate', v_upline.copy_profit_rate,
            'base_commission', v_base_commission,
            'boost_multiplier', v_boost_multiplier,
            'commission_amount', v_commission_amount,
            'copier_id', p_copier_id,
            'reference_id', p_reference_id
          )
        );

        v_total_distributed := v_total_distributed + v_commission_amount;
        v_distributions := v_distributions || jsonb_build_object(
          'affiliate_id', v_upline.affiliate_id,
          'tier_level', v_upline.tier_level,
          'rate', v_upline.copy_profit_rate,
          'base_amount', v_base_commission,
          'boost_multiplier', v_boost_multiplier,
          'boost_tier', v_boost_tier,
          'amount', v_commission_amount
        );
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'copier_id', p_copier_id,
    'profit_amount', p_profit_amount,
    'total_distributed', v_total_distributed,
    'distributions', v_distributions
  );
END;
$$;
