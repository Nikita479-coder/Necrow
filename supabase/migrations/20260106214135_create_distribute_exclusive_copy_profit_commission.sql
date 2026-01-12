/*
  # Create Copy Profit Commission Distribution Function

  ## Overview
  Creates function to distribute commissions to VIP affiliates when their referred
  users make profitable copy trades. Commission comes from platform funds (not 
  deducted from user profits).

  ## Function: distribute_exclusive_copy_profit_commission
  - Parameters:
    - p_copier_id: The user who made the profitable copy trade
    - p_profit_amount: The amount of profit (USDT)
    - p_reference_id: Reference to the copy_trade_allocation or trader_trade
  - Returns: JSONB with distribution summary

  ## Process
  1. Get upline chain for the copier (up to 5 levels)
  2. For each VIP affiliate in the chain:
     - Calculate commission: profit * copy_profit_rate / 100
     - Record in exclusive_affiliate_commissions
     - Credit to exclusive_affiliate_balances
     - Update network stats
     - Send notification

  ## Security
  - Uses SECURITY DEFINER
  - Platform pays commission (not deducted from users)
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
        
        -- Send notification to affiliate
        INSERT INTO notifications (user_id, type, title, message, read, data)
        VALUES (
          v_upline.affiliate_id,
          'affiliate_payout',
          'Copy Trading Profit Commission',
          'You earned $' || v_commission_amount || ' (' || v_upline.copy_profit_rate || '% of $' || p_profit_amount || ' profit) from a copy trade in your network (Level ' || v_upline.tier_level || ').',
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

COMMENT ON FUNCTION distribute_exclusive_copy_profit_commission IS 
  'Distributes commissions to VIP affiliates when referred users profit from copy trading. Commission paid from platform funds.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION distribute_exclusive_copy_profit_commission(uuid, numeric, uuid) TO authenticated;
