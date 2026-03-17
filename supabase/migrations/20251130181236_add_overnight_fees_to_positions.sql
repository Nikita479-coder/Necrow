/*
  # Add Overnight Fees Tracking to Positions

  1. Changes
    - Add `overnight_fees_accrued` column to futures_positions table
    - Track accumulated overnight/funding fees separately from trading fees
    - Update apply_funding_payment function to add to this column

  2. Purpose
    - Display overnight fees separately in the UI
    - Show only overnight fees, not open/close/spread fees
    - Track funding fees over time for each position
*/

-- Add overnight fees column to positions
ALTER TABLE futures_positions 
ADD COLUMN IF NOT EXISTS overnight_fees_accrued numeric(20,8) DEFAULT 0;

-- Update the apply_funding_payment function to track overnight fees
CREATE OR REPLACE FUNCTION apply_funding_payment(p_pair text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_funding_rate numeric;
  v_mark_price numeric;
  v_index_price numeric;
  v_position_record RECORD;
  v_payment_amount numeric;
  v_notional_size numeric;
BEGIN
  -- Get current mark and index prices (simplified - would come from price feed)
  SELECT mark_price INTO v_mark_price
  FROM futures_positions
  WHERE pair = p_pair AND status = 'open'
  ORDER BY last_price_update DESC
  LIMIT 1;

  -- Use mark price as index price (simplified)
  v_index_price := v_mark_price;

  -- Calculate funding rate
  v_funding_rate := calculate_funding_rate(v_mark_price, v_index_price);

  -- Apply funding to each position
  FOR v_position_record IN
    SELECT * FROM futures_positions
    WHERE pair = p_pair AND status = 'open'
  LOOP
    -- Calculate notional size
    v_notional_size := v_position_record.quantity * v_mark_price;

    -- Calculate payment amount (positive for longs pay shorts, negative for shorts pay longs)
    IF v_position_record.side = 'long' THEN
      v_payment_amount := v_notional_size * v_funding_rate;
    ELSE
      v_payment_amount := -1 * v_notional_size * v_funding_rate;
    END IF;

    -- Update position with funding payment (subtract from unrealized PnL and add to overnight fees)
    UPDATE futures_positions
    SET 
      unrealized_pnl = unrealized_pnl - v_payment_amount,
      overnight_fees_accrued = overnight_fees_accrued + ABS(v_payment_amount),
      cumulative_fees = cumulative_fees + ABS(v_payment_amount),
      last_price_update = now()
    WHERE position_id = v_position_record.position_id;

    -- Record fee collection
    INSERT INTO fee_collections (
      user_id,
      fee_type,
      amount,
      related_entity_id,
      related_entity_type
    ) VALUES (
      v_position_record.user_id,
      'funding_fee',
      ABS(v_payment_amount),
      v_position_record.position_id::text,
      'position'
    );
  END LOOP;
END;
$$;