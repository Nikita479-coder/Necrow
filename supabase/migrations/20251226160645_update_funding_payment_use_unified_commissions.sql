/*
  # Update Funding Payment to Use Unified Commission Routing

  1. Changes
    - Updates apply_funding_payment to use distribute_commissions_unified
    - This ensures funding fees respect the referrer's program choice (referral vs affiliate)
*/

CREATE OR REPLACE FUNCTION apply_funding_payment(p_pair TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_funding_rate NUMERIC;
  v_mark_price NUMERIC;
  v_index_price NUMERIC;
  v_position_record RECORD;
  v_payment_amount NUMERIC;
  v_notional_size NUMERIC;
  v_fee_collection_id UUID;
BEGIN
  -- Get mark price from an open position
  SELECT mark_price INTO v_mark_price
  FROM futures_positions
  WHERE pair = p_pair AND status = 'open'
  ORDER BY last_price_update DESC
  LIMIT 1;

  IF v_mark_price IS NULL THEN
    RETURN;
  END IF;

  v_index_price := v_mark_price;
  v_funding_rate := calculate_funding_rate(p_pair, v_mark_price, v_index_price);

  -- Process each open position
  FOR v_position_record IN
    SELECT * FROM futures_positions
    WHERE pair = p_pair AND status = 'open'
  LOOP
    v_notional_size := v_position_record.quantity * v_mark_price;

    -- Long positions pay when funding rate is positive
    -- Short positions receive when funding rate is positive
    IF v_position_record.side = 'long' THEN
      v_payment_amount := v_notional_size * v_funding_rate;
    ELSE
      v_payment_amount := -1 * v_notional_size * v_funding_rate;
    END IF;

    -- Update position with funding payment
    UPDATE futures_positions
    SET 
      unrealized_pnl = unrealized_pnl - v_payment_amount,
      overnight_fees_accrued = COALESCE(overnight_fees_accrued, 0) + ABS(v_payment_amount),
      cumulative_fees = cumulative_fees + ABS(v_payment_amount),
      last_price_update = now()
    WHERE position_id = v_position_record.position_id;

    -- Record fee collection
    INSERT INTO fee_collections (user_id, position_id, fee_type, pair, notional_size, fee_rate, fee_amount)
    VALUES (v_position_record.user_id, v_position_record.position_id, 'funding', p_pair,
      v_notional_size, ABS(v_funding_rate), ABS(v_payment_amount))
    RETURNING id INTO v_fee_collection_id;

    -- Distribute commissions using unified router (checks referral vs affiliate)
    IF ABS(v_payment_amount) > 0 THEN
      PERFORM distribute_commissions_unified(
        p_trader_id := v_position_record.user_id,
        p_transaction_id := v_fee_collection_id,
        p_trade_amount := v_notional_size,
        p_fee_amount := ABS(v_payment_amount),
        p_leverage := v_position_record.leverage
      );
    END IF;
  END LOOP;
END;
$$;
