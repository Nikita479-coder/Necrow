/*
  # Exclusive Affiliate Commission Functions

  ## Overview
  Creates functions to:
  - Check if user is an exclusive affiliate
  - Get upline chain for a user (5 levels)
  - Distribute deposit commissions
  - Distribute trading fee commissions
  - Request and process withdrawals
  - Get affiliate statistics

  ## Functions
  1. `is_exclusive_affiliate` - Check if user is enrolled
  2. `get_exclusive_upline_chain` - Get 5-level upline for user
  3. `distribute_exclusive_deposit_commission` - Pay deposit commissions
  4. `distribute_exclusive_fee_commission` - Pay trading fee share
  5. `request_exclusive_affiliate_withdrawal` - Create withdrawal request
  6. `get_exclusive_affiliate_stats` - Get dashboard statistics
*/

-- Check if user is an exclusive affiliate
CREATE OR REPLACE FUNCTION is_exclusive_affiliate(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM exclusive_affiliates
    WHERE user_id = p_user_id AND is_active = true
  );
END;
$$;

-- Get upline chain for a user (returns affiliates up to 5 levels up)
CREATE OR REPLACE FUNCTION get_exclusive_upline_chain(p_user_id uuid)
RETURNS TABLE (
  affiliate_id uuid,
  tier_level integer,
  deposit_rate numeric,
  fee_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_user_id;
  v_referrer_id uuid;
  v_level integer := 1;
  v_affiliate exclusive_affiliates;
BEGIN
  WHILE v_level <= 5 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;
    
    IF v_referrer_id IS NULL THEN
      EXIT;
    END IF;
    
    SELECT * INTO v_affiliate
    FROM exclusive_affiliates
    WHERE user_id = v_referrer_id AND is_active = true;
    
    IF FOUND THEN
      affiliate_id := v_referrer_id;
      tier_level := v_level;
      deposit_rate := (v_affiliate.deposit_commission_rates->('level_' || v_level))::numeric;
      fee_rate := (v_affiliate.fee_share_rates->('level_' || v_level))::numeric;
      RETURN NEXT;
    END IF;
    
    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
END;
$$;

-- Distribute exclusive deposit commissions
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
        
        INSERT INTO notifications (user_id, type, title, message, is_read)
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

-- Distribute exclusive trading fee commissions
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
      
      IF v_commission_amount > 0.01 THEN
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

-- Request withdrawal from exclusive affiliate balance
CREATE OR REPLACE FUNCTION request_exclusive_affiliate_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_wallet_address text,
  p_network text DEFAULT 'TRC20'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance exclusive_affiliate_balances;
  v_withdrawal_id uuid;
BEGIN
  IF NOT is_exclusive_affiliate(p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enrolled in exclusive affiliate program');
  END IF;
  
  SELECT * INTO v_balance
  FROM exclusive_affiliate_balances
  WHERE user_id = p_user_id
  FOR UPDATE;
  
  IF NOT FOUND OR v_balance.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;
  
  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;
  
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance - p_amount,
    pending_balance = pending_balance + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  INSERT INTO exclusive_affiliate_withdrawals (
    user_id,
    amount,
    currency,
    wallet_address,
    network,
    status
  ) VALUES (
    p_user_id,
    p_amount,
    'USDT',
    p_wallet_address,
    p_network,
    'pending'
  )
  RETURNING id INTO v_withdrawal_id;
  
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    p_user_id,
    'withdrawal_submitted',
    'Withdrawal Submitted',
    'Your withdrawal request for $' || p_amount || ' USDT has been submitted and is pending review.',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount
  );
END;
$$;

-- Admin process withdrawal
CREATE OR REPLACE FUNCTION admin_process_exclusive_withdrawal(
  p_admin_id uuid,
  p_withdrawal_id uuid,
  p_action text,
  p_rejection_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_withdrawal exclusive_affiliate_withdrawals;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT * INTO v_withdrawal
  FROM exclusive_affiliate_withdrawals
  WHERE id = p_withdrawal_id AND status = 'pending'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Withdrawal not found or already processed');
  END IF;
  
  IF p_action = 'approve' THEN
    UPDATE exclusive_affiliate_withdrawals
    SET 
      status = 'completed',
      processed_by = p_admin_id,
      processed_at = now(),
      updated_at = now()
    WHERE id = p_withdrawal_id;
    
    UPDATE exclusive_affiliate_balances
    SET 
      pending_balance = pending_balance - v_withdrawal.amount,
      total_withdrawn = total_withdrawn + v_withdrawal.amount,
      updated_at = now()
    WHERE user_id = v_withdrawal.user_id;
    
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_withdrawal.user_id,
      'withdrawal_approved',
      'Withdrawal Approved',
      'Your withdrawal of $' || v_withdrawal.amount || ' USDT has been approved and processed.',
      false
    );
    
  ELSIF p_action = 'reject' THEN
    UPDATE exclusive_affiliate_withdrawals
    SET 
      status = 'rejected',
      processed_by = p_admin_id,
      processed_at = now(),
      rejection_reason = p_rejection_reason,
      updated_at = now()
    WHERE id = p_withdrawal_id;
    
    UPDATE exclusive_affiliate_balances
    SET 
      available_balance = available_balance + v_withdrawal.amount,
      pending_balance = pending_balance - v_withdrawal.amount,
      updated_at = now()
    WHERE user_id = v_withdrawal.user_id;
    
    INSERT INTO notifications (user_id, type, title, message, is_read)
    VALUES (
      v_withdrawal.user_id,
      'withdrawal_rejected',
      'Withdrawal Rejected',
      'Your withdrawal of $' || v_withdrawal.amount || ' USDT was rejected. Reason: ' || COALESCE(p_rejection_reason, 'No reason provided'),
      false
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'action', p_action,
    'withdrawal_id', p_withdrawal_id
  );
END;
$$;

-- Get exclusive affiliate statistics
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
    'balance', jsonb_build_object(
      'available', COALESCE(v_balance.available_balance, 0),
      'pending', COALESCE(v_balance.pending_balance, 0),
      'total_earned', COALESCE(v_balance.total_earned, 0),
      'total_withdrawn', COALESCE(v_balance.total_withdrawn, 0),
      'deposit_commissions', COALESCE(v_balance.deposit_commissions_earned, 0),
      'fee_share', COALESCE(v_balance.fee_share_earned, 0)
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

-- Update network counts when a new user signs up
CREATE OR REPLACE FUNCTION update_exclusive_affiliate_network_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_upline RECORD;
BEGIN
  IF NEW.referred_by IS NOT NULL THEN
    FOR v_upline IN SELECT * FROM get_exclusive_upline_chain(NEW.id) LOOP
      INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
      VALUES (v_upline.affiliate_id)
      ON CONFLICT (affiliate_id) DO NOTHING;
      
      UPDATE exclusive_affiliate_network_stats
      SET 
        level_1_count = CASE WHEN v_upline.tier_level = 1 THEN level_1_count + 1 ELSE level_1_count END,
        level_2_count = CASE WHEN v_upline.tier_level = 2 THEN level_2_count + 1 ELSE level_2_count END,
        level_3_count = CASE WHEN v_upline.tier_level = 3 THEN level_3_count + 1 ELSE level_3_count END,
        level_4_count = CASE WHEN v_upline.tier_level = 4 THEN level_4_count + 1 ELSE level_4_count END,
        level_5_count = CASE WHEN v_upline.tier_level = 5 THEN level_5_count + 1 ELSE level_5_count END,
        updated_at = now()
      WHERE affiliate_id = v_upline.affiliate_id;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_exclusive_network_on_signup ON user_profiles;
CREATE TRIGGER trg_update_exclusive_network_on_signup
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_exclusive_affiliate_network_on_signup();
