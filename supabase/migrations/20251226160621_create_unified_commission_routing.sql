/*
  # Unified Commission Routing for Referral vs Affiliate Programs

  1. Overview
    - Creates a unified function to route fee commissions to either referral or affiliate program
    - Checks the referrer's active_program setting to determine which system to use
    - Referral: Simple direct commission to referrer with VIP-based rates
    - Affiliate: Multi-tier commissions up to 5 levels

  2. New Functions
    - `distribute_commissions_unified` - Main router function that checks program type and delegates

  3. Changes
    - All fee-collecting functions will use this unified router
    - Ensures consistent commission distribution across all fee types
*/

-- Create the unified commission distribution function
CREATE OR REPLACE FUNCTION distribute_commissions_unified(
  p_trader_id UUID,
  p_transaction_id UUID,
  p_trade_amount NUMERIC,
  p_fee_amount NUMERIC,
  p_leverage INTEGER DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_referrer_id UUID;
  v_referrer_program TEXT;
BEGIN
  -- Skip if no fee to distribute
  IF p_fee_amount <= 0 THEN
    RETURN;
  END IF;

  -- Get the trader's referrer
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_trader_id;

  -- No referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  -- Check what program the referrer is on
  SELECT COALESCE(active_program, 'referral') INTO v_referrer_program
  FROM user_profiles
  WHERE id = v_referrer_id;

  -- Route to appropriate commission system
  IF v_referrer_program = 'affiliate' THEN
    -- Use multi-tier affiliate system
    PERFORM distribute_multi_tier_commissions(
      p_trader_id := p_trader_id,
      p_trade_amount := p_trade_amount,
      p_fee_amount := p_fee_amount,
      p_trade_id := p_transaction_id
    );
  ELSE
    -- Use simple referral system (default)
    PERFORM distribute_trading_fees(
      p_user_id := p_trader_id,
      p_transaction_id := p_transaction_id,
      p_trade_amount := p_trade_amount,
      p_fee_amount := p_fee_amount,
      p_leverage := p_leverage
    );
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION distribute_commissions_unified TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_commissions_unified TO service_role;
