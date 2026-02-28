/*
  # Fix Exclusive Affiliate Deposit Commission Tracking

  ## Problem
  Tier 2+ deposit commissions were being credited to main wallets instead of exclusive_affiliate_balances
  No commission records were being created in exclusive_affiliate_commissions table
  Dashboard couldn't display commission history for exclusive affiliates

  ## Solution
  Updated distribute_exclusive_deposit_commission to properly:
  1. Create commission records in exclusive_affiliate_commissions (for dashboard visibility)
  2. Credit exclusive_affiliate_balances table (withdrawable balance)
  3. Update network statistics for all 10 tier levels
  4. Send notifications to affiliates  
  5. Track tier-specific earnings for reporting

  ## Changes
  - Add commission tracking to exclusive_affiliate_commissions
  - Credit exclusive_affiliate_balances instead of main wallet
  - Update network_stats for all 10 levels
  - Fix notification column name (read instead of is_read)
*/

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
  v_upline record;
  v_commission_amount numeric;
  v_total_distributed numeric := 0;
  v_distributions jsonb := '[]'::jsonb;
BEGIN
  -- Loop through all uplines in the exclusive affiliate chain (up to 10 levels)
  FOR v_upline IN
    SELECT *
    FROM get_exclusive_upline_chain(p_depositor_id)
  LOOP
    -- Calculate commission for this tier level
    v_commission_amount := ROUND(p_deposit_amount * v_upline.deposit_rate, 2);

    IF v_commission_amount > 0 THEN
      -- 1. Create commission record in exclusive_affiliate_commissions
      -- This is for dashboard visibility and tracking
      INSERT INTO exclusive_affiliate_commissions (
        affiliate_id,
        source_user_id,
        commission_type,
        tier_level,
        commission_amount,
        source_amount,
        commission_rate,
        reference_id,
        reference_type,
        status
      )
      VALUES (
        v_upline.affiliate_id,
        p_depositor_id,
        'deposit',
        v_upline.tier_level,
        v_commission_amount,
        p_deposit_amount,
        v_upline.deposit_rate,
        p_reference_id,
        'deposit',
        'credited'
      );

      -- 2. Credit exclusive_affiliate_balances table
      -- This is the withdrawable balance for exclusive affiliates
      INSERT INTO exclusive_affiliate_balances (
        user_id,
        available_balance,
        total_earned,
        deposit_commissions_earned
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
        deposit_commissions_earned = exclusive_affiliate_balances.deposit_commissions_earned + v_commission_amount,
        updated_at = now();

      -- 3. Update network stats for this affiliate
      -- Initialize record if it doesn't exist
      INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
      VALUES (v_upline.affiliate_id)
      ON CONFLICT (affiliate_id) DO NOTHING;

      -- Update tier-specific earnings
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
        updated_at = now()
      WHERE affiliate_id = v_upline.affiliate_id;

      -- 5. Send notification to affiliate
      INSERT INTO notifications (user_id, type, title, message, read)
      VALUES (
        v_upline.affiliate_id,
        'affiliate_payout',
        'Deposit Commission Received',
        'You earned $' || TRIM(TO_CHAR(v_commission_amount, 'FM999999999.00')) || ' (Level ' || v_upline.tier_level || ' - ' || TRIM(TO_CHAR(v_upline.deposit_rate, 'FM999999999.##')) || '%) from a deposit in your network.',
        false
      );

      -- Track distribution for return value
      v_total_distributed := v_total_distributed + v_commission_amount;
      v_distributions := v_distributions || jsonb_build_object(
        'affiliate_id', v_upline.affiliate_id,
        'tier_level', v_upline.tier_level,
        'rate', v_upline.deposit_rate,
        'amount', v_commission_amount
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'total_distributed', v_total_distributed,
    'distributions', v_distributions
  );
END;
$$;