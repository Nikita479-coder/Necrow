/*
  # Create Unified Commission Distribution

  ## Overview
  Creates a single entry point for commission distribution that routes
  to the appropriate system based on the referrer's active program.

  ## Logic
  1. Check if trader has a referrer
  2. Get referrer's active program
  3. Route to appropriate distribution system:
     - 'referral': Uses simple distribute_trading_fees
     - 'affiliate': Uses multi-tier distribute_multi_tier_commissions

  ## Security
  Uses SECURITY DEFINER with restricted search_path
*/

-- Unified commission distribution function
CREATE OR REPLACE FUNCTION distribute_commissions(
  p_trader_id UUID,
  p_transaction_id UUID,
  p_trade_amount NUMERIC,
  p_fee_amount NUMERIC,
  p_leverage INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_referrer_program TEXT;
  v_result JSONB;
  v_commissions_distributed JSONB := '[]'::jsonb;
BEGIN
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_trader_id;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No referrer found',
      'commissions_paid', 0
    );
  END IF;

  SELECT COALESCE(active_program, 'referral') INTO v_referrer_program
  FROM user_profiles
  WHERE id = v_referrer_id;

  IF v_referrer_program = 'affiliate' THEN
    SELECT jsonb_agg(row_to_json(r)) INTO v_commissions_distributed
    FROM (
      SELECT * FROM distribute_multi_tier_commissions(
        p_trader_id := p_trader_id,
        p_trade_amount := p_trade_amount,
        p_fee_amount := p_fee_amount,
        p_trade_id := p_transaction_id
      )
    ) r;

    RETURN jsonb_build_object(
      'success', true,
      'program', 'affiliate',
      'commissions', COALESCE(v_commissions_distributed, '[]'::jsonb)
    );
  ELSE
    PERFORM distribute_trading_fees(
      p_user_id := p_trader_id,
      p_transaction_id := p_transaction_id,
      p_trade_amount := p_trade_amount,
      p_fee_amount := p_fee_amount,
      p_leverage := p_leverage
    );

    RETURN jsonb_build_object(
      'success', true,
      'program', 'referral',
      'message', 'Simple referral commission distributed'
    );
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION distribute_commissions(UUID, UUID, NUMERIC, NUMERIC, INTEGER) TO authenticated;
