/*
  # Fix Funding Rate Function Call

  1. Changes
    - Update apply_funding_payment to call calculate_funding_rate with correct parameters
    - Pass the pair parameter to calculate_funding_rate

  2. Purpose
    - Fix the function signature mismatch error
*/

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

  -- Calculate funding rate (pass pair parameter)
  v_funding_rate := calculate_funding_rate(p_pair, v_mark_price, v_index_price);

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
      overnight_fees_accrued = COALESCE(overnight_fees_accrued, 0) + ABS(v_payment_amount),
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