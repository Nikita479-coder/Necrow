/*
  # Add Cross Margin Liquidation Price Updates

  ## Description
  Creates triggers to automatically update cross margin liquidation prices
  when account equity changes (positions close, PnL changes, etc.)

  ## New Functions

  ### update_cross_margin_liquidations()
  Recalculates liquidation prices for all cross margin positions when triggered
  - Called after position changes
  - Called after PnL updates
  - Ensures liquidation prices stay accurate as account equity changes

  ## Triggers
  - After position is created/updated
  - After position is closed (affects remaining positions)
  - After unrealized PnL updates (from price changes)

  ## Important Notes
  - Only affects cross margin positions
  - Isolated margin liquidation prices remain static
  - Keeps liquidation prices in sync with total account equity
*/

-- Function to update all cross margin liquidation prices for a user
CREATE OR REPLACE FUNCTION update_cross_margin_liquidations(p_user_id uuid)
RETURNS void AS $$
DECLARE
  v_position record;
  v_new_liq_price numeric;
BEGIN
  -- Update liquidation price for all open cross margin positions
  FOR v_position IN
    SELECT position_id, side, entry_price, quantity, leverage, pair, mark_price
    FROM futures_positions
    WHERE user_id = p_user_id
      AND status = 'open'
      AND margin_mode = 'cross'
  LOOP
    -- Calculate new liquidation price based on current account equity
    v_new_liq_price := calculate_liquidation_price(
      p_user_id,
      v_position.side,
      v_position.entry_price,
      v_position.quantity,
      v_position.mark_price,
      v_position.leverage,
      'cross',
      v_position.pair
    );
    
    -- Update the liquidation price
    UPDATE futures_positions
    SET liquidation_price = v_new_liq_price,
        last_price_update = now()
    WHERE position_id = v_position.position_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to update cross margin liquidations when positions change
CREATE OR REPLACE FUNCTION trigger_update_cross_margin_liquidations()
RETURNS TRIGGER AS $$
BEGIN
  -- Update all cross margin positions for this user
  PERFORM update_cross_margin_liquidations(
    COALESCE(NEW.user_id, OLD.user_id)
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger after position insert/update/delete
DROP TRIGGER IF EXISTS on_position_change_update_cross_liquidations ON futures_positions;
CREATE TRIGGER on_position_change_update_cross_liquidations
  AFTER INSERT OR UPDATE OR DELETE ON futures_positions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_cross_margin_liquidations();

-- Also update when PnL changes significantly (after price updates)
-- This is already handled by the on_price_update_recalc_pnl trigger
-- which updates unrealized_pnl, which then triggers the above trigger