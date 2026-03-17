/*
  # Fix Cross Margin Liquidation Calculation

  ## Description
  Adds proper cross margin liquidation price calculation that considers
  the entire account equity, not just individual position margin.

  ## Key Differences

  ### Isolated Margin
  - Liquidation when position margin reaches 0
  - Only uses margin allocated to that specific position
  - More conservative (higher) liquidation prices
  - Example: $15,000 position margin → liquidates at -$15,000 loss

  ### Cross Margin
  - Liquidation when TOTAL ACCOUNT EQUITY reaches 0
  - Can use entire account balance across all positions
  - More aggressive (lower) liquidation prices  
  - Example: $18,000 total equity → liquidates at -$18,000 total loss

  ## New Functions

  ### calculate_cross_margin_liquidation_price_long()
  Calculates liquidation price for LONG positions in cross margin mode
  - Uses total account equity instead of just position margin
  - Considers all open positions and available balance

  ### calculate_cross_margin_liquidation_price_short()
  Calculates liquidation price for SHORT positions in cross margin mode
  - Uses total account equity instead of just position margin
  - Considers all open positions and available balance

  ### get_total_account_equity()
  Helper function to get user's total account equity
  - Available balance + locked balance + total unrealized PnL

  ## Important Notes
  - Cross margin = more aggressive, can lose entire account
  - Isolated margin = safer, can only lose position margin
  - Liquidation prices will be MUCH lower in cross margin mode
*/

-- Get total account equity for a user
CREATE OR REPLACE FUNCTION get_total_account_equity(p_user_id uuid)
RETURNS numeric AS $$
DECLARE
  v_available numeric;
  v_locked numeric;
  v_unrealized_pnl numeric;
BEGIN
  -- Get wallet balances
  SELECT available_balance, locked_balance
  INTO v_available, v_locked
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;
  
  v_available := COALESCE(v_available, 0);
  v_locked := COALESCE(v_locked, 0);
  
  -- Get total unrealized PnL from all open positions
  SELECT COALESCE(SUM(unrealized_pnl), 0)
  INTO v_unrealized_pnl
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'open';
  
  -- Total equity = available + locked + unrealized PnL
  RETURN v_available + v_locked + v_unrealized_pnl;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate cross margin liquidation price for LONG positions
CREATE OR REPLACE FUNCTION calculate_cross_margin_liquidation_price_long(
  p_user_id uuid,
  p_entry_price numeric,
  p_quantity numeric,
  p_current_mark_price numeric,
  p_leverage integer,
  p_pair text DEFAULT 'BTCUSDT'
)
RETURNS numeric AS $$
DECLARE
  v_total_equity numeric;
  v_mmr numeric;
  v_position_value numeric;
  v_maintenance_margin numeric;
  v_liq_price numeric;
BEGIN
  -- Get total account equity
  v_total_equity := get_total_account_equity(p_user_id);
  
  -- Get maintenance margin rate
  v_mmr := get_maintenance_margin_rate(p_leverage);
  
  -- Calculate position value at current price
  v_position_value := p_quantity * p_current_mark_price;
  
  -- Calculate maintenance margin required
  v_maintenance_margin := v_position_value * v_mmr;
  
  -- For LONG: liquidation when total_equity + (liq_price - current_price) * quantity <= maintenance_margin
  -- Solving for liq_price:
  -- liq_price = current_price - (total_equity - maintenance_margin) / quantity
  
  v_liq_price := p_current_mark_price - ((v_total_equity - v_maintenance_margin) / p_quantity);
  
  -- Ensure liquidation price is positive
  IF v_liq_price < 0 THEN
    RETURN 0;
  END IF;
  
  RETURN v_liq_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate cross margin liquidation price for SHORT positions
CREATE OR REPLACE FUNCTION calculate_cross_margin_liquidation_price_short(
  p_user_id uuid,
  p_entry_price numeric,
  p_quantity numeric,
  p_current_mark_price numeric,
  p_leverage integer,
  p_pair text DEFAULT 'BTCUSDT'
)
RETURNS numeric AS $$
DECLARE
  v_total_equity numeric;
  v_mmr numeric;
  v_position_value numeric;
  v_maintenance_margin numeric;
  v_liq_price numeric;
BEGIN
  -- Get total account equity
  v_total_equity := get_total_account_equity(p_user_id);
  
  -- Get maintenance margin rate
  v_mmr := get_maintenance_margin_rate(p_leverage);
  
  -- Calculate position value at current price
  v_position_value := p_quantity * p_current_mark_price;
  
  -- Calculate maintenance margin required
  v_maintenance_margin := v_position_value * v_mmr;
  
  -- For SHORT: liquidation when total_equity - (liq_price - current_price) * quantity <= maintenance_margin
  -- Solving for liq_price:
  -- liq_price = current_price + (total_equity - maintenance_margin) / quantity
  
  v_liq_price := p_current_mark_price + ((v_total_equity - v_maintenance_margin) / p_quantity);
  
  RETURN v_liq_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- Update liquidation price calculation function to support both margin modes
CREATE OR REPLACE FUNCTION calculate_liquidation_price(
  p_user_id uuid,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_current_mark_price numeric,
  p_leverage integer,
  p_margin_mode text,
  p_pair text DEFAULT 'BTCUSDT'
)
RETURNS numeric AS $$
BEGIN
  IF p_margin_mode = 'cross' THEN
    -- Use cross margin calculation (considers total account equity)
    IF p_side = 'long' THEN
      RETURN calculate_cross_margin_liquidation_price_long(
        p_user_id, p_entry_price, p_quantity, p_current_mark_price, p_leverage, p_pair
      );
    ELSE
      RETURN calculate_cross_margin_liquidation_price_short(
        p_user_id, p_entry_price, p_quantity, p_current_mark_price, p_leverage, p_pair
      );
    END IF;
  ELSE
    -- Use isolated margin calculation (only position margin)
    IF p_side = 'long' THEN
      RETURN calculate_liquidation_price_long(p_entry_price, p_leverage, p_pair);
    ELSE
      RETURN calculate_liquidation_price_short(p_entry_price, p_leverage, p_pair);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;