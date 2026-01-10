/*
  # Extend Exclusive Affiliate System to 10 Levels

  ## Overview
  Extends the exclusive affiliate program from 5 levels to 10 levels for enhanced
  multi-tier commission tracking. This supports higher-tier affiliates who need
  deeper network commission structures.

  ## Changes

  ### 1. Schema Updates
  - Add level_6 through level_10 columns to exclusive_affiliate_network_stats
  - Update tier_level constraint on exclusive_affiliate_commissions to allow 1-10

  ### 2. Function Updates
  - get_exclusive_upline_chain: Extended to 10 levels
  - distribute_exclusive_deposit_commission: Track levels 6-10 earnings
  - distribute_exclusive_fee_commission: Track levels 6-10 earnings
  - update_exclusive_affiliate_network_on_signup: Count levels 6-10
  - get_exclusive_affiliate_stats: Return all 10 levels

  ## Security
  - All existing RLS policies remain in effect
  - No new security changes required
*/

-- Add level 6-10 columns to network stats
ALTER TABLE exclusive_affiliate_network_stats
  ADD COLUMN IF NOT EXISTS level_6_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_7_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_8_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_9_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_10_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_6_earnings NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_7_earnings NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_8_earnings NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_9_earnings NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS level_10_earnings NUMERIC DEFAULT 0;

-- Update tier_level constraint on commissions table to allow 1-10
ALTER TABLE exclusive_affiliate_commissions
  DROP CONSTRAINT IF EXISTS exclusive_affiliate_commissions_tier_level_check;

ALTER TABLE exclusive_affiliate_commissions
  ADD CONSTRAINT exclusive_affiliate_commissions_tier_level_check
  CHECK (tier_level >= 1 AND tier_level <= 10);

-- Drop functions that have return type changes
DROP FUNCTION IF EXISTS get_exclusive_upline_chain(uuid);
DROP FUNCTION IF EXISTS admin_get_exclusive_affiliates();
DROP FUNCTION IF EXISTS get_exclusive_affiliate_referrals(uuid);

-- Update get_exclusive_upline_chain to support 10 levels
CREATE OR REPLACE FUNCTION get_exclusive_upline_chain(p_user_id uuid)
RETURNS TABLE (
  affiliate_id uuid,
  tier_level integer,
  deposit_rate numeric,
  fee_rate numeric,
  copy_profit_rate numeric
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
  WHILE v_level <= 10 LOOP
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
      deposit_rate := COALESCE((v_affiliate.deposit_commission_rates->('level_' || v_level))::numeric, 0);
      fee_rate := COALESCE((v_affiliate.fee_share_rates->('level_' || v_level))::numeric, 0);
      copy_profit_rate := COALESCE((v_affiliate.copy_profit_rates->('level_' || v_level))::numeric, 0);
      RETURN NEXT;
    END IF;
    
    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
END;
$$;

-- Update distribute_exclusive_deposit_commission for 10 levels
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
          level_5_earnings = CASE WHEN v_upline.tier_level = 5 THEN level_5_earnings + v_commission_amount ELSE level_5_earnings END,
          level_6_earnings = CASE WHEN v_upline.tier_level = 6 THEN level_6_earnings + v_commission_amount ELSE level_6_earnings END,
          level_7_earnings = CASE WHEN v_upline.tier_level = 7 THEN level_7_earnings + v_commission_amount ELSE level_7_earnings END,
          level_8_earnings = CASE WHEN v_upline.tier_level = 8 THEN level_8_earnings + v_commission_amount ELSE level_8_earnings END,
          level_9_earnings = CASE WHEN v_upline.tier_level = 9 THEN level_9_earnings + v_commission_amount ELSE level_9_earnings END,
          level_10_earnings = CASE WHEN v_upline.tier_level = 10 THEN level_10_earnings + v_commission_amount ELSE level_10_earnings END
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

-- Update distribute_exclusive_fee_commission for 10 levels
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
          level_5_earnings = CASE WHEN v_upline.tier_level = 5 THEN level_5_earnings + v_commission_amount ELSE level_5_earnings END,
          level_6_earnings = CASE WHEN v_upline.tier_level = 6 THEN level_6_earnings + v_commission_amount ELSE level_6_earnings END,
          level_7_earnings = CASE WHEN v_upline.tier_level = 7 THEN level_7_earnings + v_commission_amount ELSE level_7_earnings END,
          level_8_earnings = CASE WHEN v_upline.tier_level = 8 THEN level_8_earnings + v_commission_amount ELSE level_8_earnings END,
          level_9_earnings = CASE WHEN v_upline.tier_level = 9 THEN level_9_earnings + v_commission_amount ELSE level_9_earnings END,
          level_10_earnings = CASE WHEN v_upline.tier_level = 10 THEN level_10_earnings + v_commission_amount ELSE level_10_earnings END
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

-- Update network counts trigger for 10 levels
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
        level_6_count = CASE WHEN v_upline.tier_level = 6 THEN level_6_count + 1 ELSE level_6_count END,
        level_7_count = CASE WHEN v_upline.tier_level = 7 THEN level_7_count + 1 ELSE level_7_count END,
        level_8_count = CASE WHEN v_upline.tier_level = 8 THEN level_8_count + 1 ELSE level_8_count END,
        level_9_count = CASE WHEN v_upline.tier_level = 9 THEN level_9_count + 1 ELSE level_9_count END,
        level_10_count = CASE WHEN v_upline.tier_level = 10 THEN level_10_count + 1 ELSE level_10_count END,
        updated_at = now()
      WHERE affiliate_id = v_upline.affiliate_id;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Update get_exclusive_affiliate_stats to return 10 levels
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

-- Recreate admin_get_exclusive_affiliates to return 10-level data
CREATE OR REPLACE FUNCTION admin_get_exclusive_affiliates()
RETURNS TABLE (
  affiliate_id uuid,
  user_id uuid,
  email text,
  full_name text,
  username text,
  referral_code text,
  deposit_commission_rates jsonb,
  fee_share_rates jsonb,
  copy_profit_rates jsonb,
  is_active boolean,
  enrolled_at timestamptz,
  enrolled_by_email text,
  available_balance numeric,
  pending_balance numeric,
  total_earned numeric,
  total_withdrawn numeric,
  deposit_commissions_earned numeric,
  fee_share_earned numeric,
  copy_profit_earned numeric,
  network_size bigint,
  this_month_earnings numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT
    ea.id as affiliate_id,
    ea.user_id,
    get_user_email(ea.user_id) as email,
    up.full_name,
    up.username,
    up.referral_code,
    ea.deposit_commission_rates,
    ea.fee_share_rates,
    COALESCE(ea.copy_profit_rates, '{}'::jsonb) as copy_profit_rates,
    ea.is_active,
    ea.created_at as enrolled_at,
    get_user_email(ea.enrolled_by) as enrolled_by_email,
    COALESCE(eab.available_balance, 0) as available_balance,
    COALESCE(eab.pending_balance, 0) as pending_balance,
    COALESCE(eab.total_earned, 0) as total_earned,
    COALESCE(eab.total_withdrawn, 0) as total_withdrawn,
    COALESCE(eab.deposit_commissions_earned, 0) as deposit_commissions_earned,
    COALESCE(eab.fee_share_earned, 0) as fee_share_earned,
    COALESCE(eab.copy_profit_earned, 0) as copy_profit_earned,
    COALESCE(eans.level_1_count, 0) + COALESCE(eans.level_2_count, 0) + COALESCE(eans.level_3_count, 0) + 
    COALESCE(eans.level_4_count, 0) + COALESCE(eans.level_5_count, 0) + COALESCE(eans.level_6_count, 0) +
    COALESCE(eans.level_7_count, 0) + COALESCE(eans.level_8_count, 0) + COALESCE(eans.level_9_count, 0) +
    COALESCE(eans.level_10_count, 0) as network_size,
    COALESCE(eans.this_month_earnings, 0) as this_month_earnings
  FROM exclusive_affiliates ea
  JOIN user_profiles up ON up.id = ea.user_id
  LEFT JOIN exclusive_affiliate_balances eab ON eab.user_id = ea.user_id
  LEFT JOIN exclusive_affiliate_network_stats eans ON eans.affiliate_id = ea.user_id
  ORDER BY ea.created_at DESC;
END;
$$;

-- Update admin enroll function for 10 levels
CREATE OR REPLACE FUNCTION admin_enroll_exclusive_affiliate(
  p_admin_id uuid,
  p_user_email text,
  p_deposit_rates jsonb DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}',
  p_fee_rates jsonb DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}',
  p_copy_profit_rates jsonb DEFAULT '{"level_1": 10, "level_2": 5, "level_3": 4, "level_4": 3, "level_5": 2, "level_6": 0, "level_7": 0, "level_8": 0, "level_9": 0, "level_10": 0}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = p_admin_id AND is_admin = true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;
  
  SELECT id INTO v_target_user_id
  FROM auth.users
  WHERE email = p_user_email;
  
  IF v_target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
  
  IF EXISTS (SELECT 1 FROM exclusive_affiliates WHERE user_id = v_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is already enrolled');
  END IF;
  
  INSERT INTO exclusive_affiliates (
    user_id,
    enrolled_by,
    deposit_commission_rates,
    fee_share_rates,
    copy_profit_rates,
    is_active
  ) VALUES (
    v_target_user_id,
    p_admin_id,
    p_deposit_rates,
    p_fee_rates,
    p_copy_profit_rates,
    true
  );
  
  INSERT INTO exclusive_affiliate_balances (user_id)
  VALUES (v_target_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  
  INSERT INTO exclusive_affiliate_network_stats (affiliate_id)
  VALUES (v_target_user_id)
  ON CONFLICT (affiliate_id) DO NOTHING;
  
  INSERT INTO admin_action_logs (admin_id, action_type, target_user_id, action_description, metadata)
  VALUES (
    p_admin_id,
    'enroll_exclusive_affiliate',
    v_target_user_id,
    'Enrolled user in exclusive affiliate program',
    jsonb_build_object(
      'deposit_rates', p_deposit_rates,
      'fee_rates', p_fee_rates,
      'copy_profit_rates', p_copy_profit_rates
    )
  );
  
  INSERT INTO notifications (user_id, type, title, message, is_read)
  VALUES (
    v_target_user_id,
    'system',
    'Welcome to Exclusive Affiliate Program!',
    'You have been enrolled in our exclusive multi-level affiliate program with up to 10 levels of commissions. Start sharing your referral link to earn!',
    false
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_target_user_id
  );
END;
$$;

-- Recreate get_exclusive_affiliate_referrals to support 10 levels
CREATE OR REPLACE FUNCTION get_exclusive_affiliate_referrals(p_affiliate_id uuid)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  level integer,
  registered_at timestamptz,
  total_deposits numeric,
  trading_volume numeric,
  eligible boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_enrolled_at timestamptz;
BEGIN
  SELECT created_at INTO v_enrolled_at
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_id;
  
  IF v_enrolled_at IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  WITH RECURSIVE referral_tree AS (
    SELECT 
      up.id,
      up.full_name,
      up.username,
      up.referred_by,
      up.created_at,
      1 as level
    FROM user_profiles up
    WHERE up.referred_by = p_affiliate_id
    
    UNION ALL
    
    SELECT 
      up.id,
      up.full_name,
      up.username,
      up.referred_by,
      up.created_at,
      rt.level + 1
    FROM user_profiles up
    JOIN referral_tree rt ON up.referred_by = rt.id
    WHERE rt.level < 10
  )
  SELECT 
    rt.id as user_id,
    get_user_email(rt.id) as email,
    rt.full_name,
    rt.username,
    rt.level,
    rt.created_at as registered_at,
    COALESCE(rs.total_deposits, 0) as total_deposits,
    COALESCE(rs.total_volume, 0) as trading_volume,
    rt.created_at >= v_enrolled_at as eligible
  FROM referral_tree rt
  LEFT JOIN referral_stats rs ON rs.user_id = rt.id
  ORDER BY rt.level, rt.created_at DESC;
END;
$$;
