/*
  # Fix Exclusive Deposit Commission Stats Table Reference

  1. Problem
    - Function was referencing non-existent 'exclusive_affiliate_stats' table
    - Correct table is 'exclusive_affiliate_network_stats'

  2. Solution
    - Update to use correct table and column names
*/

DROP FUNCTION IF EXISTS distribute_exclusive_deposit_commission(uuid, numeric, uuid);

CREATE OR REPLACE FUNCTION distribute_exclusive_deposit_commission(
  p_depositor_id uuid,
  p_deposit_amount numeric,
  p_reference_id uuid
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
  v_commissions_paid jsonb := '[]'::jsonb;
  v_wallet_id uuid;
  v_level_earnings_col text;
BEGIN
  FOR v_upline IN
    SELECT * FROM get_exclusive_upline_chain(p_depositor_id)
    WHERE deposit_rate > 0
  LOOP
    v_commission_amount := ROUND(p_deposit_amount * (v_upline.deposit_rate / 100), 2);
    
    IF v_commission_amount >= 0.01 THEN
      SELECT id INTO v_wallet_id
      FROM wallets
      WHERE user_id = v_upline.affiliate_id
      AND currency = 'USDT'
      AND wallet_type = 'main';
      
      IF v_wallet_id IS NULL THEN
        INSERT INTO wallets (user_id, currency, wallet_type, balance)
        VALUES (v_upline.affiliate_id, 'USDT', 'main', 0)
        RETURNING id INTO v_wallet_id;
      END IF;
      
      UPDATE wallets
      SET balance = balance + v_commission_amount,
          updated_at = now()
      WHERE id = v_wallet_id;
      
      INSERT INTO transactions (
        user_id,
        transaction_type,
        amount,
        currency,
        status,
        details
      ) VALUES (
        v_upline.affiliate_id,
        'affiliate_commission',
        v_commission_amount,
        'USDT',
        'completed',
        jsonb_build_object(
          'type', 'deposit_commission',
          'depositor_id', p_depositor_id,
          'deposit_id', p_reference_id,
          'deposit_amount', p_deposit_amount,
          'tier_level', v_upline.tier_level,
          'commission_rate', v_upline.deposit_rate
        )
      );
      
      INSERT INTO notifications (user_id, type, title, message, read)
      VALUES (
        v_upline.affiliate_id,
        'affiliate_payout',
        'Deposit Commission Received',
        'You earned $' || TRIM(TO_CHAR(v_commission_amount, 'FM999999999.00')) || ' (Level ' || v_upline.tier_level || ' - ' || TRIM(TO_CHAR(v_upline.deposit_rate, 'FM999999999.##')) || '%) from a deposit in your network.',
        false
      );
      
      v_total_distributed := v_total_distributed + v_commission_amount;
      v_commissions_paid := v_commissions_paid || jsonb_build_object(
        'affiliate_id', v_upline.affiliate_id,
        'tier_level', v_upline.tier_level,
        'rate', v_upline.deposit_rate,
        'amount', v_commission_amount
      );
      
      v_level_earnings_col := 'level_' || v_upline.tier_level || '_earnings';
      
      EXECUTE format(
        'UPDATE exclusive_affiliate_network_stats
         SET %I = COALESCE(%I, 0) + $1,
             this_month_earnings = COALESCE(this_month_earnings, 0) + $1,
             updated_at = now()
         WHERE affiliate_id = $2',
        v_level_earnings_col, v_level_earnings_col
      ) USING v_commission_amount, v_upline.affiliate_id;
    END IF;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'total_distributed', v_total_distributed,
    'commissions', v_commissions_paid
  );
END;
$$;
