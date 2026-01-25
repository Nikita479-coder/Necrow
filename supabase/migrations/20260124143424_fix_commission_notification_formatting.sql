/*
  # Fix Commission Notification Number Formatting

  ## Summary
  Fixes the display of commission amounts in notifications by properly formatting
  numbers to 2 decimal places without excessive trailing zeros.

  ## Changes
  - Updates `distribute_exclusive_deposit_commission` function
  - Updates `distribute_exclusive_copy_profit_commission` function
  - Uses proper number formatting in notification messages

  ## Example
  Before: $0.03 (5% of $0.5846871879904500000000000000000000000000000000000000)
  After: $0.03 (5% of $0.58 profit)
*/

-- Fix deposit commission notification formatting
CREATE OR REPLACE FUNCTION distribute_exclusive_deposit_commission(
  p_depositor_id uuid,
  p_deposit_amount numeric,
  p_reference_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_upline RECORD;
  v_commission_amount numeric;
  v_total_distributed numeric := 0;
  v_distributions jsonb := '[]'::jsonb;
BEGIN
  FOR v_upline IN SELECT * FROM get_exclusive_upline_chain(p_depositor_id) LOOP
    IF v_upline.deposit_rate > 0 THEN
      v_commission_amount := ROUND((p_deposit_amount * v_upline.deposit_rate / 100)::numeric, 2);

      IF v_commission_amount > 0 THEN
        INSERT INTO exclusive_affiliate_commissions (
          affiliate_id,
          source_user_id,
          tier_level,
          commission_type,
          source_amount,
          commission_rate,
          commission_amount,
          reference_id,
          reference_type,
          status
        ) VALUES (
          v_upline.affiliate_id,
          p_depositor_id,
          v_upline.tier_level,
          'deposit',
          p_deposit_amount,
          v_upline.deposit_rate,
          v_commission_amount,
          p_reference_id,
          'deposit',
          'credited'
        );

        INSERT INTO exclusive_affiliate_balances (user_id, available_balance, total_earned, deposit_commissions_earned)
        VALUES (v_upline.affiliate_id, v_commission_amount, v_commission_amount, v_commission_amount)
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = exclusive_affiliate_balances.available_balance + v_commission_amount,
          total_earned = exclusive_affiliate_balances.total_earned + v_commission_amount,
          deposit_commissions_earned = exclusive_affiliate_balances.deposit_commissions_earned + v_commission_amount,
          updated_at = now();

        INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
        VALUES (v_upline.affiliate_id)
        ON CONFLICT (affiliate_id) DO UPDATE SET
          this_month_earnings = exclusive_affiliate_network_stats.this_month_earnings + v_commission_amount,
          updated_at = now();

        UPDATE exclusive_affiliate_network_stats
        SET
          level_1_earnings = CASE WHEN v_upline.tier_level = 1 THEN level_1_earnings + v_commission_amount ELSE level_1_earnings END,
          level_2_earnings = CASE WHEN v_upline.tier_level = 2 THEN level_2_earnings + v_commission_amount ELSE level_2_earnings END,
          level_3_earnings = CASE WHEN v_upline.tier_level = 3 THEN level_3_earnings + v_commission_amount ELSE level_3_earnings END,
          level_4_earnings = CASE WHEN v_upline.tier_level = 4 THEN level_4_earnings + v_commission_amount ELSE level_4_earnings END,
          level_5_earnings = CASE WHEN v_upline.tier_level = 5 THEN level_5_earnings + v_commission_amount ELSE level_5_earnings END
        WHERE affiliate_id = v_upline.affiliate_id;

        -- Fixed: Format numbers properly in notification message
        INSERT INTO notifications (user_id, type, title, message, is_read)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Deposit Commission Received',
          'You earned $' || TRIM(TO_CHAR(v_commission_amount, 'FM999999999.00')) || ' (Level ' || v_upline.tier_level || ' - ' || TRIM(TO_CHAR(v_upline.deposit_rate, 'FM999999999.##')) || '%) from a deposit in your network.',
          false
        );

        v_total_distributed := v_total_distributed + v_commission_amount;
        v_distributions := v_distributions || jsonb_build_object(
          'affiliate_id', v_upline.affiliate_id,
          'tier_level', v_upline.tier_level,
          'rate', v_upline.deposit_rate,
          'amount', v_commission_amount
        );
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'total_distributed', v_total_distributed,
    'distributions', v_distributions
  );
END;
$$;

-- Fix copy trading profit commission notification formatting
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
  v_upline RECORD;
  v_commission_amount numeric;
  v_total_distributed numeric := 0;
  v_distributions jsonb := '[]'::jsonb;
BEGIN
  -- Only distribute if profit is positive
  IF p_profit_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No commission distributed - no profit',
      'total_distributed', 0,
      'distributions', '[]'::jsonb
    );
  END IF;

  -- Iterate through the upline chain
  FOR v_upline IN SELECT * FROM get_exclusive_upline_chain(p_copier_id) LOOP
    -- Check if copy_profit_rate is valid
    IF v_upline.copy_profit_rate > 0 THEN
      v_commission_amount := ROUND((p_profit_amount * v_upline.copy_profit_rate / 100)::numeric, 2);

      -- Only distribute if commission is meaningful (> $0.01)
      IF v_commission_amount >= 0.01 THEN
        -- Record commission in tracking table
        INSERT INTO exclusive_affiliate_commissions (
          affiliate_id,
          source_user_id,
          tier_level,
          commission_type,
          source_amount,
          commission_rate,
          commission_amount,
          reference_id,
          reference_type,
          status
        ) VALUES (
          v_upline.affiliate_id,
          p_copier_id,
          v_upline.tier_level,
          'copy_profit',
          p_profit_amount,
          v_upline.copy_profit_rate,
          v_commission_amount,
          p_reference_id,
          'copy_trade',
          'credited'
        );

        -- Credit to affiliate balance
        INSERT INTO exclusive_affiliate_balances (
          user_id,
          available_balance,
          total_earned,
          copy_profit_earned
        )
        VALUES (
          v_upline.affiliate_id,
          v_commission_amount,
          v_commission_amount,
          v_commission_amount
        )
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = exclusive_affiliate_balances.available_balance + v_commission_amount,
          total_earned = exclusive_affiliate_balances.total_earned + v_commission_amount,
          copy_profit_earned = exclusive_affiliate_balances.copy_profit_earned + v_commission_amount,
          updated_at = now();

        -- Update network statistics
        INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
        VALUES (v_upline.affiliate_id)
        ON CONFLICT (affiliate_id) DO UPDATE SET
          this_month_earnings = exclusive_affiliate_network_stats.this_month_earnings + v_commission_amount,
          updated_at = now();

        -- Update level-specific earnings
        UPDATE exclusive_affiliate_network_stats
        SET
          level_1_earnings = CASE WHEN v_upline.tier_level = 1 THEN level_1_earnings + v_commission_amount ELSE level_1_earnings END,
          level_2_earnings = CASE WHEN v_upline.tier_level = 2 THEN level_2_earnings + v_commission_amount ELSE level_2_earnings END,
          level_3_earnings = CASE WHEN v_upline.tier_level = 3 THEN level_3_earnings + v_commission_amount ELSE level_3_earnings END,
          level_4_earnings = CASE WHEN v_upline.tier_level = 4 THEN level_4_earnings + v_commission_amount ELSE level_4_earnings END,
          level_5_earnings = CASE WHEN v_upline.tier_level = 5 THEN level_5_earnings + v_commission_amount ELSE level_5_earnings END
        WHERE affiliate_id = v_upline.affiliate_id;

        -- Fixed: Format numbers properly in notification message
        INSERT INTO notifications (user_id, type, title, message, read, data)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Copy Trading Profit Commission',
          'You earned $' || TRIM(TO_CHAR(v_commission_amount, 'FM999999999.00')) || ' (' || TRIM(TO_CHAR(v_upline.copy_profit_rate, 'FM999999999.##')) || '% of $' || TRIM(TO_CHAR(p_profit_amount, 'FM999999999.00')) || ' profit) from a copy trade in your network (Level ' || v_upline.tier_level || ').',
          false,
          jsonb_build_object(
            'commission_type', 'copy_profit',
            'tier_level', v_upline.tier_level,
            'profit_amount', p_profit_amount,
            'commission_rate', v_upline.copy_profit_rate,
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

COMMENT ON FUNCTION distribute_exclusive_deposit_commission IS
  'Distributes deposit commissions to VIP affiliates with properly formatted notification messages';

COMMENT ON FUNCTION distribute_exclusive_copy_profit_commission IS
  'Distributes commissions to VIP affiliates when referred users profit from copy trading with properly formatted notification messages';
