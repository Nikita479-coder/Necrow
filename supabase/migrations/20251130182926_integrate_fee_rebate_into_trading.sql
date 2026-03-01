/*
  # Integrate Fee Rebate into Trading Functions

  1. Changes
    - Update trading functions to apply fee rebates automatically
    - Modify fee collection to trigger rebate calculation
    - Add rebate tracking to fee_collections table

  2. Purpose
    - Automatically apply VIP rebates when fees are charged
    - Reduce effective trading costs for users
    - Track rebates for transparency
*/

-- Add rebate tracking columns to fee_collections
ALTER TABLE fee_collections 
ADD COLUMN IF NOT EXISTS rebate_amount numeric(20,8) DEFAULT 0,
ADD COLUMN IF NOT EXISTS rebate_rate numeric(5,2) DEFAULT 0;

-- Trigger to apply fee rebate when fee is collected
CREATE OR REPLACE FUNCTION trigger_apply_fee_rebate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rebate_amount numeric;
BEGIN
  -- Apply rebate for trading fees (maker, taker, funding, liquidation)
  IF NEW.fee_type IN ('maker', 'taker', 'funding', 'liquidation', 'spread') THEN
    v_rebate_amount := apply_fee_rebate(
      NEW.user_id,
      NEW.fee_amount,
      NEW.fee_type,
      NEW.position_id::text
    );

    -- Update the fee_collections record with rebate info
    UPDATE fee_collections
    SET 
      rebate_amount = v_rebate_amount,
      rebate_rate = (
        SELECT rebate_rate 
        FROM user_vip_status 
        WHERE user_id = NEW.user_id
      )
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on fee_collections
DROP TRIGGER IF EXISTS on_fee_collected_apply_rebate ON fee_collections;
CREATE TRIGGER on_fee_collected_apply_rebate
  AFTER INSERT ON fee_collections
  FOR EACH ROW
  EXECUTE FUNCTION trigger_apply_fee_rebate();

-- Update referral commission calculation to use VIP level
CREATE OR REPLACE FUNCTION calculate_referral_commission(
  p_referrer_id uuid,
  p_fee_amount numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_commission_rate numeric;
  v_commission_amount numeric;
BEGIN
  -- Get referrer's commission rate from VIP status
  SELECT commission_rate INTO v_commission_rate
  FROM user_vip_status
  WHERE user_id = p_referrer_id;

  -- If no VIP status found, use VIP 1 default (10%)
  IF v_commission_rate IS NULL THEN
    v_commission_rate := 10;
  END IF;

  -- Calculate commission amount
  v_commission_amount := p_fee_amount * (v_commission_rate / 100);

  RETURN v_commission_amount;
END;
$$;