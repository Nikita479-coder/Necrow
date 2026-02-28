/*
  # Fix Exclusive Affiliate Notification Column

  ## Problem
  The distribute_exclusive_deposit_commission and distribute_exclusive_fee_commission
  functions use the old column name 'is_read' instead of 'read'

  ## Solution
  Update both functions to use the correct column name 'read'
*/

-- Fix distribute_exclusive_deposit_commission
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
        
        INSERT INTO notifications (user_id, type, title, message, read)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Deposit Commission Received',
          'You earned $' || v_commission_amount || ' (Level ' || v_upline.tier_level || ' - ' || v_upline.deposit_rate || '%) from a deposit in your network.',
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

-- Fix distribute_exclusive_fee_commission
CREATE OR REPLACE FUNCTION distribute_exclusive_fee_commission(
  p_trader_id uuid,
  p_fee_amount numeric,
  p_reference_id uuid DEFAULT NULL,
  p_reference_type text DEFAULT 'trade'
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
  FOR v_upline IN SELECT * FROM get_exclusive_upline_chain(p_trader_id) LOOP
    IF v_upline.fee_rate > 0 THEN
      v_commission_amount := ROUND((p_fee_amount * v_upline.fee_rate / 100)::numeric, 2);
      
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
          p_trader_id,
          v_upline.tier_level,
          'trading_fee',
          p_fee_amount,
          v_upline.fee_rate,
          v_commission_amount,
          p_reference_id,
          p_reference_type,
          'credited'
        );
        
        INSERT INTO exclusive_affiliate_balances (user_id, available_balance, total_earned, fee_share_earned)
        VALUES (v_upline.affiliate_id, v_commission_amount, v_commission_amount, v_commission_amount)
        ON CONFLICT (user_id) DO UPDATE SET
          available_balance = exclusive_affiliate_balances.available_balance + v_commission_amount,
          total_earned = exclusive_affiliate_balances.total_earned + v_commission_amount,
          fee_share_earned = exclusive_affiliate_balances.fee_share_earned + v_commission_amount,
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
        
        INSERT INTO notifications (user_id, type, title, message, read)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Fee Commission Received',
          'You earned $' || v_commission_amount || ' (Level ' || v_upline.tier_level || ' - ' || v_upline.fee_rate || '%) from trading fees in your network.',
          false
        );
        
        v_total_distributed := v_total_distributed + v_commission_amount;
        v_distributions := v_distributions || jsonb_build_object(
          'affiliate_id', v_upline.affiliate_id,
          'tier_level', v_upline.tier_level,
          'rate', v_upline.fee_rate,
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