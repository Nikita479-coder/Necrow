/*
  # Fix Apply Fee Rebate and Admin Users List

  ## Problems Fixed
  1. apply_fee_rebate uses 'futures_margin' wallet type which is not allowed
     - Constraint only allows: main, assets, copy, futures, card
     - For futures fees, should credit to futures_margin_wallets table instead
  
  2. get_admin_users_list VIP tier casting issue
     - current_level is integer, shouldn't use 'None' as default

  ## Changes
  1. Fix apply_fee_rebate to properly route futures rebates
  2. Fix get_admin_users_list VIP tier handling
*/

-- Drop existing function with exact signature
DROP FUNCTION IF EXISTS apply_fee_rebate(uuid, numeric, text, text);

-- Create fixed version
CREATE OR REPLACE FUNCTION apply_fee_rebate(
  p_user_id uuid,
  p_fee_amount numeric,
  p_fee_type text,
  p_related_entity_id text DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rebate_rate numeric;
  v_rebate_amount numeric;
  v_is_futures_fee boolean;
BEGIN
  -- Get user's rebate rate from VIP status
  SELECT rebate_rate INTO v_rebate_rate
  FROM user_vip_status
  WHERE user_id = p_user_id;

  IF v_rebate_rate IS NULL THEN
    v_rebate_rate := 5;
  END IF;

  -- Calculate rebate amount
  v_rebate_amount := p_fee_amount * (v_rebate_rate / 100);

  -- Determine if this is a futures-related fee
  v_is_futures_fee := p_fee_type IN ('futures_open', 'futures_close', 'funding', 'liquidation', 'maker', 'taker');

  IF v_is_futures_fee THEN
    -- Credit to futures_margin_wallets (separate table, not wallets)
    INSERT INTO futures_margin_wallets (user_id, available_balance)
    VALUES (p_user_id, v_rebate_amount)
    ON CONFLICT (user_id) DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + v_rebate_amount,
      updated_at = now();
  ELSE
    -- Credit to main wallet in wallets table
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'main', v_rebate_amount)
    ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET
      balance = wallets.balance + v_rebate_amount,
      updated_at = now();
  END IF;

  -- Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    p_user_id,
    'fee_rebate',
    v_rebate_amount,
    'USDT',
    'completed',
    format('VIP Fee Rebate (%s%%) on %s fee', v_rebate_rate, p_fee_type)
  );

  RETURN v_rebate_amount;
END;
$$;

-- Fix get_admin_users_list to handle VIP tier properly
DROP FUNCTION IF EXISTS get_admin_users_list();

CREATE OR REPLACE FUNCTION get_admin_users_list()
RETURNS TABLE (
  id uuid,
  email text,
  username text,
  full_name text,
  kyc_status text,
  kyc_level integer,
  created_at timestamptz,
  total_balance numeric,
  open_positions bigint,
  unrealized_pnl numeric,
  vip_tier text,
  has_referrer boolean,
  referral_count integer
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  is_admin boolean;
BEGIN
  is_admin := COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false);
  
  IF NOT is_admin THEN
    is_admin := EXISTS (
      SELECT 1 FROM admin_staff 
      WHERE admin_staff.id = auth.uid() AND is_active = true
    );
  END IF;
  
  IF NOT is_admin THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH wallet_totals AS (
    SELECT w.user_id, SUM(w.balance) as total
    FROM wallets w
    GROUP BY w.user_id
  ),
  position_stats AS (
    SELECT 
      fp.user_id,
      COUNT(*) as pos_count,
      SUM(fp.unrealized_pnl) as total_pnl
    FROM futures_positions fp
    WHERE fp.status = 'open'
    GROUP BY fp.user_id
  )
  SELECT 
    up.id,
    COALESCE(au.email, 'N/A')::text,
    up.username::text,
    up.full_name::text,
    COALESCE(up.kyc_status, 'none')::text,
    COALESCE(up.kyc_level, 0)::integer,
    up.created_at,
    COALESCE(wt.total, 0)::numeric,
    COALESCE(ps.pos_count, 0)::bigint,
    COALESCE(ps.total_pnl, 0)::numeric,
    COALESCE(get_vip_tier_name(uvs.current_level), 'VIP 1')::text as vip_tier,
    (up.referred_by IS NOT NULL)::boolean,
    COALESCE(rs.total_referrals, 0)::integer
  FROM user_profiles up
  LEFT JOIN auth.users au ON au.id = up.id
  LEFT JOIN wallet_totals wt ON wt.user_id = up.id
  LEFT JOIN position_stats ps ON ps.user_id = up.id
  LEFT JOIN user_vip_status uvs ON uvs.user_id = up.id
  LEFT JOIN referral_stats rs ON rs.user_id = up.id
  ORDER BY up.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION apply_fee_rebate TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_users_list TO authenticated;
