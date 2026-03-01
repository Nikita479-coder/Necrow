/*
  # Fix Multi-Tier Trading Commissions to Skip Exclusive Affiliates
  
  1. Changes
    - Add check for exclusive affiliates in upline to distribute_multi_tier_commissions
    - Skip regular commissions if any exclusive affiliate exists in upline
    
  2. Reason
    - Function was distributing regular affiliate commissions even when 
      exclusive affiliates exist in the upline
    - Causes double commission distribution
*/

CREATE OR REPLACE FUNCTION distribute_multi_tier_commissions(
  p_trader_id uuid,
  p_trade_amount numeric,
  p_fee_amount numeric,
  p_trade_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_trader_id;
  v_referrer_id uuid;
  v_level integer := 1;
  v_commission_rate numeric;
  v_commission_amount numeric;
  v_trader_email text;
BEGIN
  -- CRITICAL: Skip if exclusive affiliate in upline
  IF has_exclusive_affiliate_in_upline(p_trader_id) THEN
    RETURN;
  END IF;

  -- CRITICAL: Skip if trader hasn't made a completed deposit
  IF NOT has_completed_deposit(p_trader_id) THEN
    RETURN;
  END IF;

  SELECT email INTO v_trader_email
  FROM auth.users
  WHERE id = p_trader_id;

  WHILE v_level <= 5 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;

    IF v_referrer_id IS NULL THEN
      EXIT;
    END IF;

    v_commission_rate := CASE v_level
      WHEN 1 THEN 40.0
      WHEN 2 THEN 10.0
      WHEN 3 THEN 5.0
      WHEN 4 THEN 3.0
      WHEN 5 THEN 2.0
    END;

    v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

    INSERT INTO affiliate_commissions (
      affiliate_id,
      trader_id,
      trade_id,
      tier_level,
      trade_amount,
      fee_amount,
      commission_rate,
      commission_amount
    ) VALUES (
      v_referrer_id,
      p_trader_id,
      p_trade_id,
      v_level,
      p_trade_amount,
      p_fee_amount,
      v_commission_rate,
      v_commission_amount
    );

    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_referrer_id, 'USDT', 'main', 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

    UPDATE wallets
    SET balance = balance + v_commission_amount,
        updated_at = now()
    WHERE user_id = v_referrer_id
      AND currency = 'USDT'
      AND wallet_type = 'main';

    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details,
      confirmed_at
    ) VALUES (
      v_referrer_id,
      'affiliate_commission',
      'USDT',
      v_commission_amount,
      'completed',
      format('Tier %s affiliate commission from network trading', v_level),
      now()
    );

    PERFORM send_notification(
      v_referrer_id,
      'affiliate_payout',
      format('Affiliate Payout: +%s USDT', ROUND(v_commission_amount, 2)),
      format('You earned %s USDT (%s%%) as Tier %s commission from your network. Trader: %s',
        ROUND(v_commission_amount, 2),
        ROUND(v_commission_rate, 0),
        v_level,
        COALESCE(SUBSTRING(v_trader_email FROM 1 FOR 3) || '***', 'User')
      ),
      jsonb_build_object(
        'commission_amount', v_commission_amount,
        'currency', 'USDT',
        'commission_rate', v_commission_rate,
        'tier_level', v_level,
        'trader_id', p_trader_id,
        'trader_email', COALESCE(SUBSTRING(v_trader_email FROM 1 FOR 3) || '***', 'User'),
        'trade_amount', p_trade_amount,
        'fee_amount', p_fee_amount
      )
    );

    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
END;
$$;
