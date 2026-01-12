/*
  # Fix Commission Routing to Respect Active Program Selection

  ## Summary
  This migration fixes a critical bug where ALL trading commissions were being
  routed to the affiliate system regardless of the referrer's `active_program` setting.

  ## Problem
  Trading functions were calling `distribute_multi_tier_commissions` directly,
  which is the affiliate-only distribution system. They should be calling
  `distribute_commissions` which checks the referrer's `active_program` and routes to:
  - 'referral': Uses `distribute_trading_fees` (simple 1-tier referral)
  - 'affiliate': Uses `distribute_multi_tier_commissions` (5-tier affiliate)

  ## Solution
  1. Create a trigger on `fee_collections` table that automatically calls
     `distribute_commissions` whenever a fee is recorded
  2. This ensures ALL fee collection points (open, close, funding, liquidation)
     properly route to the correct commission system based on active_program

  ## Security
  Uses SECURITY DEFINER with restricted search_path
*/

-- Drop any existing trigger first
DROP TRIGGER IF EXISTS trigger_commission_on_fee_collection ON fee_collections;
DROP FUNCTION IF EXISTS trigger_distribute_commissions_on_fee();

-- Create the trigger function that routes to the correct commission system
CREATE OR REPLACE FUNCTION trigger_distribute_commissions_on_fee()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_transaction_id UUID;
BEGIN
  -- Only process if fee amount is positive
  IF NEW.fee_amount <= 0 THEN
    RETURN NEW;
  END IF;

  -- Check if this user has a referrer
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = NEW.user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get or create a transaction ID for tracking
  v_transaction_id := COALESCE(NEW.position_id, gen_random_uuid());

  -- Call the unified commission distribution function
  -- This will check the referrer's active_program and route accordingly:
  -- - 'referral' -> distribute_trading_fees (simple referral)
  -- - 'affiliate' -> distribute_multi_tier_commissions (5-tier affiliate)
  PERFORM distribute_commissions(
    p_trader_id := NEW.user_id,
    p_transaction_id := v_transaction_id,
    p_trade_amount := COALESCE(NEW.notional_size, NEW.fee_amount * 100),
    p_fee_amount := NEW.fee_amount,
    p_leverage := 1
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the transaction
  RAISE WARNING 'Commission distribution failed for user %: %', NEW.user_id, SQLERRM;
  RETURN NEW;
END;
$$;

-- Create the trigger on fee_collections
CREATE TRIGGER trigger_commission_on_fee_collection
  AFTER INSERT ON fee_collections
  FOR EACH ROW
  EXECUTE FUNCTION trigger_distribute_commissions_on_fee();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION trigger_distribute_commissions_on_fee() TO authenticated;

-- Also update the unified distribute_commissions function to handle edge cases better
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
  -- Get the trader's referrer
  SELECT referred_by INTO v_referrer_id
  FROM user_profiles
  WHERE id = p_trader_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No referrer found',
      'commissions_paid', 0
    );
  END IF;

  -- Get the REFERRER's active program setting
  -- This is the key: we check the referrer's preference, not the trader's
  SELECT COALESCE(active_program, 'referral') INTO v_referrer_program
  FROM user_profiles
  WHERE id = v_referrer_id;

  -- Route to the appropriate distribution system based on referrer's active_program
  IF v_referrer_program = 'affiliate' THEN
    -- Use multi-tier affiliate commission distribution (5 tiers)
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
      'referrer_id', v_referrer_id,
      'commissions', COALESCE(v_commissions_distributed, '[]'::jsonb)
    );
  ELSE
    -- Use simple referral commission distribution (1 tier)
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
      'referrer_id', v_referrer_id,
      'message', 'Simple referral commission distributed'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'trader_id', p_trader_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION distribute_commissions(UUID, UUID, NUMERIC, NUMERIC, INTEGER) TO authenticated;
