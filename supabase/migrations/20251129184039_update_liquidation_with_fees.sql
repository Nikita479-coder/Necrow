/*
  # Update Liquidation to Include Liquidation Fees

  1. Updates
    - Modify liquidation process to charge 0.5% liquidation fee
    - Split fee: 80% insurance fund, 20% exchange revenue
    - Support partial liquidation to preserve capital
    - Track all liquidation fees in fee_collections

  2. Changes
    - `check_and_liquidate_positions` includes liquidation fee
    - Insurance fund receives 80% of liquidation fees
    - Exchange receives 20% of liquidation fees
*/

-- Updated liquidation check with fees
CREATE OR REPLACE FUNCTION check_and_liquidate_positions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_should_liquidate boolean;
  v_notional_value numeric;
  v_liquidation_fee numeric;
  v_remaining_margin numeric;
BEGIN
  FOR v_position IN
    SELECT * FROM futures_positions
    WHERE status = 'open'
  LOOP
    v_should_liquidate := false;

    IF v_position.margin_mode = 'isolated' THEN
      -- Check isolated margin liquidation
      IF v_position.side = 'long' THEN
        IF v_position.mark_price <= v_position.liquidation_price THEN
          v_should_liquidate := true;
        END IF;
      ELSE
        IF v_position.mark_price >= v_position.liquidation_price THEN
          v_should_liquidate := true;
        END IF;
      END IF;
    ELSE
      -- Check cross margin liquidation
      DECLARE
        v_total_margin numeric;
        v_total_unrealized_pnl numeric;
        v_total_maintenance numeric;
      BEGIN
        SELECT 
          COALESCE(SUM(margin_allocated), 0),
          COALESCE(SUM(unrealized_pnl), 0),
          COALESCE(SUM(quantity * mark_price * maintenance_margin_rate), 0)
        INTO 
          v_total_margin,
          v_total_unrealized_pnl,
          v_total_maintenance
        FROM futures_positions
        WHERE user_id = v_position.user_id
          AND status = 'open'
          AND margin_mode = 'cross';

        IF (v_total_margin + v_total_unrealized_pnl) <= v_total_maintenance THEN
          v_should_liquidate := true;
        END IF;
      END;
    END IF;

    IF v_should_liquidate THEN
      -- Calculate notional value
      v_notional_value := v_position.quantity * v_position.mark_price;

      -- Calculate and apply liquidation fee
      v_liquidation_fee := calculate_liquidation_fee(
        v_position.user_id,
        v_position.position_id,
        v_notional_value
      );

      -- Calculate remaining margin after fee
      v_remaining_margin := v_position.margin_allocated - v_liquidation_fee;
      
      IF v_remaining_margin < 0 THEN
        v_remaining_margin := 0;
      END IF;

      -- Update position as liquidated
      UPDATE futures_positions
      SET
        status = 'liquidated',
        realized_pnl = -v_position.margin_allocated,
        cumulative_fees = cumulative_fees + v_liquidation_fee,
        closed_at = NOW(),
        last_price_update = NOW()
      WHERE position_id = v_position.position_id;

      -- Record liquidation transaction
      INSERT INTO transactions (
        user_id,
        transaction_type,
        amount,
        currency,
        status,
        metadata
      ) VALUES (
        v_position.user_id,
        'liquidation',
        v_position.margin_allocated,
        'USDT',
        'completed',
        jsonb_build_object(
          'pair', v_position.pair,
          'side', v_position.side,
          'entry_price', v_position.entry_price,
          'liquidation_price', v_position.mark_price,
          'notional_value', v_notional_value,
          'liquidation_fee', v_liquidation_fee,
          'position_id', v_position.position_id
        )
      );
    END IF;
  END LOOP;
END;
$$;

-- Partial liquidation function (reduce position size instead of full liquidation)
CREATE OR REPLACE FUNCTION partial_liquidate_position(
  p_position_id uuid,
  p_reduction_percent numeric DEFAULT 0.25
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_reduce_quantity numeric;
  v_reduce_margin numeric;
  v_notional_value numeric;
  v_liquidation_fee numeric;
  v_new_quantity numeric;
  v_new_margin numeric;
  v_new_liquidation_price numeric;
BEGIN
  -- Get position
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Calculate reduction amounts
  v_reduce_quantity := v_position.quantity * p_reduction_percent;
  v_reduce_margin := v_position.margin_allocated * p_reduction_percent;

  -- Calculate notional value of reduced portion
  v_notional_value := v_reduce_quantity * v_position.mark_price;

  -- Calculate liquidation fee on reduced portion
  v_liquidation_fee := calculate_liquidation_fee(
    v_position.user_id,
    v_position.position_id,
    v_notional_value
  );

  -- Calculate new values
  v_new_quantity := v_position.quantity - v_reduce_quantity;
  v_new_margin := v_position.margin_allocated - v_reduce_margin;

  -- Recalculate liquidation price
  IF v_position.side = 'long' THEN
    v_new_liquidation_price := v_position.entry_price * (1 - (v_new_margin / (v_new_quantity * v_position.entry_price)) + v_position.maintenance_margin_rate);
  ELSE
    v_new_liquidation_price := v_position.entry_price * (1 + (v_new_margin / (v_new_quantity * v_position.entry_price)) - v_position.maintenance_margin_rate);
  END IF;

  -- Update position with reduced size
  UPDATE futures_positions
  SET
    quantity = v_new_quantity,
    margin_allocated = v_new_margin,
    liquidation_price = v_new_liquidation_price,
    cumulative_fees = cumulative_fees + v_liquidation_fee,
    last_price_update = NOW()
  WHERE position_id = p_position_id;

  -- Record partial liquidation
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    v_position.user_id,
    'partial_liquidation',
    v_reduce_margin,
    'USDT',
    'completed',
    jsonb_build_object(
      'pair', v_position.pair,
      'reduction_percent', p_reduction_percent,
      'reduced_quantity', v_reduce_quantity,
      'reduced_margin', v_reduce_margin,
      'liquidation_fee', v_liquidation_fee,
      'new_quantity', v_new_quantity,
      'new_margin', v_new_margin,
      'position_id', p_position_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'partial_liquidation', true,
    'reduced_quantity', v_reduce_quantity,
    'remaining_quantity', v_new_quantity,
    'liquidation_fee', v_liquidation_fee,
    'new_liquidation_price', v_new_liquidation_price
  );
END;
$$;
