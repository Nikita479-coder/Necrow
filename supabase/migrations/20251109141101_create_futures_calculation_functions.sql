/*
  # Futures Trading Calculation Functions

  ## Description
  This migration creates all the calculation functions for fees, margin requirements,
  liquidation prices, and leverage validation.

  ## Functions Created

  ### Fee Calculations
  - get_trading_fee_rate() - Get maker or taker fee for a pair
  - calculate_trading_fee() - Calculate exact fee amount
  - calculate_liquidation_fee_amount() - Calculate 0.4% liquidation fee

  ### Margin Calculations
  - get_maintenance_margin_rate() - Get MMR based on leverage tier
  - calculate_initial_margin() - Calculate required margin for position
  - calculate_liquidation_price_long() - Exact liquidation price for longs
  - calculate_liquidation_price_short() - Exact liquidation price for shorts
  - distance_to_liquidation_percent() - How close to liquidation

  ### Leverage Validation
  - get_max_leverage_for_pair() - Pair-specific max leverage
  - get_max_leverage_for_user() - User-specific max leverage
  - get_effective_max_leverage() - Actual usable max leverage
  - validate_leverage_request() - Check if leverage is allowed

  ### Position Calculations
  - calculate_unrealized_pnl() - Current profit/loss
  - calculate_position_value() - Total position value
  - calculate_max_position_size() - Maximum size based on balance
  - calculate_roe() - Return on equity percentage

  ## Important Formulas

  ### Liquidation Price (Long):
  liq_price = entry_price × leverage / (leverage + 1 - leverage × (MMR + liq_fee + taker_fee + buffer))

  ### Liquidation Price (Short):
  liq_price = entry_price × leverage / (leverage - 1 + leverage × (MMR + liq_fee + taker_fee + buffer))

  ### Initial Margin:
  margin = (quantity × entry_price) / leverage

  ### Unrealized PnL (Long):
  pnl = (mark_price - entry_price) × quantity

  ### Unrealized PnL (Short):
  pnl = (entry_price - mark_price) × quantity
*/

-- Get trading fee rate for a pair
CREATE OR REPLACE FUNCTION get_trading_fee_rate(
  p_pair text,
  p_is_maker boolean DEFAULT true
)
RETURNS numeric AS $$
DECLARE
  v_fee numeric;
BEGIN
  IF p_is_maker THEN
    SELECT maker_fee INTO v_fee
    FROM trading_pairs_config
    WHERE pair = p_pair;
  ELSE
    SELECT taker_fee INTO v_fee
    FROM trading_pairs_config
    WHERE pair = p_pair;
  END IF;
  
  RETURN COALESCE(v_fee, 0.0004); -- Default to taker fee if not found
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate trading fee amount
CREATE OR REPLACE FUNCTION calculate_trading_fee(
  p_pair text,
  p_quantity numeric,
  p_price numeric,
  p_is_maker boolean DEFAULT false
)
RETURNS numeric AS $$
DECLARE
  v_position_value numeric;
  v_fee_rate numeric;
BEGIN
  v_position_value := p_quantity * p_price;
  v_fee_rate := get_trading_fee_rate(p_pair, p_is_maker);
  
  RETURN v_position_value * v_fee_rate;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate liquidation fee
CREATE OR REPLACE FUNCTION calculate_liquidation_fee_amount(
  p_pair text,
  p_quantity numeric,
  p_liquidation_price numeric
)
RETURNS numeric AS $$
DECLARE
  v_position_value numeric;
  v_liq_fee_rate numeric;
BEGIN
  SELECT liquidation_fee INTO v_liq_fee_rate
  FROM trading_pairs_config
  WHERE pair = p_pair;
  
  v_position_value := p_quantity * p_liquidation_price;
  
  RETURN v_position_value * COALESCE(v_liq_fee_rate, 0.004);
END;
$$ LANGUAGE plpgsql STABLE;

-- Get maintenance margin rate based on leverage
CREATE OR REPLACE FUNCTION get_maintenance_margin_rate(p_leverage integer)
RETURNS numeric AS $$
DECLARE
  v_mmr numeric;
BEGIN
  SELECT maintenance_margin_rate INTO v_mmr
  FROM leverage_tiers
  WHERE p_leverage >= min_leverage AND p_leverage <= max_leverage
  LIMIT 1;
  
  RETURN COALESCE(v_mmr, 0.005); -- Default to 0.5% if not found
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate initial margin required
CREATE OR REPLACE FUNCTION calculate_initial_margin(
  p_quantity numeric,
  p_price numeric,
  p_leverage integer
)
RETURNS numeric AS $$
BEGIN
  RETURN (p_quantity * p_price) / p_leverage;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate liquidation price for LONG positions
CREATE OR REPLACE FUNCTION calculate_liquidation_price_long(
  p_entry_price numeric,
  p_leverage integer,
  p_pair text DEFAULT 'BTCUSDT'
)
RETURNS numeric AS $$
DECLARE
  v_mmr numeric;
  v_liq_fee numeric;
  v_taker_fee numeric;
  v_buffer numeric := 0.0005;
  v_numerator numeric;
  v_denominator numeric;
BEGIN
  -- Get maintenance margin rate
  v_mmr := get_maintenance_margin_rate(p_leverage);
  
  -- Get fees
  SELECT liquidation_fee, taker_fee INTO v_liq_fee, v_taker_fee
  FROM trading_pairs_config
  WHERE pair = p_pair;
  
  v_liq_fee := COALESCE(v_liq_fee, 0.004);
  v_taker_fee := COALESCE(v_taker_fee, 0.0004);
  
  -- Formula: entry_price × leverage / (leverage + 1 - leverage × (MMR + liq_fee + taker_fee + buffer))
  v_numerator := p_entry_price * p_leverage;
  v_denominator := p_leverage + 1 - (p_leverage * (v_mmr + v_liq_fee + v_taker_fee + v_buffer));
  
  -- Prevent division by zero or negative liquidation price
  IF v_denominator <= 0 THEN
    RETURN 0;
  END IF;
  
  RETURN v_numerator / v_denominator;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate liquidation price for SHORT positions
CREATE OR REPLACE FUNCTION calculate_liquidation_price_short(
  p_entry_price numeric,
  p_leverage integer,
  p_pair text DEFAULT 'BTCUSDT'
)
RETURNS numeric AS $$
DECLARE
  v_mmr numeric;
  v_liq_fee numeric;
  v_taker_fee numeric;
  v_buffer numeric := 0.0005;
  v_numerator numeric;
  v_denominator numeric;
BEGIN
  -- Get maintenance margin rate
  v_mmr := get_maintenance_margin_rate(p_leverage);
  
  -- Get fees
  SELECT liquidation_fee, taker_fee INTO v_liq_fee, v_taker_fee
  FROM trading_pairs_config
  WHERE pair = p_pair;
  
  v_liq_fee := COALESCE(v_liq_fee, 0.004);
  v_taker_fee := COALESCE(v_taker_fee, 0.0004);
  
  -- Formula: entry_price × leverage / (leverage - 1 + leverage × (MMR + liq_fee + taker_fee + buffer))
  v_numerator := p_entry_price * p_leverage;
  v_denominator := p_leverage - 1 + (p_leverage * (v_mmr + v_liq_fee + v_taker_fee + v_buffer));
  
  -- Prevent division by zero
  IF v_denominator <= 0 THEN
    RETURN p_entry_price * 1000; -- Return very high price for shorts
  END IF;
  
  RETURN v_numerator / v_denominator;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get max leverage for a trading pair
CREATE OR REPLACE FUNCTION get_max_leverage_for_pair(p_pair text)
RETURNS integer AS $$
DECLARE
  v_max_leverage integer;
BEGIN
  SELECT max_leverage INTO v_max_leverage
  FROM trading_pairs_config
  WHERE pair = p_pair AND is_active = true;
  
  RETURN COALESCE(v_max_leverage, 25); -- Default to 25x
END;
$$ LANGUAGE plpgsql STABLE;

-- Get max leverage for a user based on KYC
CREATE OR REPLACE FUNCTION get_max_leverage_for_user(p_user_id uuid)
RETURNS integer AS $$
DECLARE
  v_max_leverage integer;
BEGIN
  SELECT max_allowed_leverage INTO v_max_leverage
  FROM user_leverage_limits
  WHERE user_id = p_user_id;
  
  RETURN COALESCE(v_max_leverage, 20); -- Default to 20x for unverified
END;
$$ LANGUAGE plpgsql STABLE;

-- Get effective max leverage (minimum of pair and user limits)
CREATE OR REPLACE FUNCTION get_effective_max_leverage(
  p_user_id uuid,
  p_pair text
)
RETURNS integer AS $$
DECLARE
  v_pair_max integer;
  v_user_max integer;
BEGIN
  v_pair_max := get_max_leverage_for_pair(p_pair);
  v_user_max := get_max_leverage_for_user(p_user_id);
  
  RETURN LEAST(v_pair_max, v_user_max);
END;
$$ LANGUAGE plpgsql STABLE;

-- Validate leverage request
CREATE OR REPLACE FUNCTION validate_leverage_request(
  p_user_id uuid,
  p_pair text,
  p_requested_leverage integer
)
RETURNS boolean AS $$
DECLARE
  v_max_allowed integer;
BEGIN
  v_max_allowed := get_effective_max_leverage(p_user_id, p_pair);
  
  RETURN p_requested_leverage >= 1 AND p_requested_leverage <= v_max_allowed;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate unrealized PnL for a position
CREATE OR REPLACE FUNCTION calculate_unrealized_pnl(
  p_side text,
  p_entry_price numeric,
  p_mark_price numeric,
  p_quantity numeric
)
RETURNS numeric AS $$
BEGIN
  IF p_side = 'long' THEN
    RETURN (p_mark_price - p_entry_price) * p_quantity;
  ELSE -- short
    RETURN (p_entry_price - p_mark_price) * p_quantity;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate position value
CREATE OR REPLACE FUNCTION calculate_position_value(
  p_quantity numeric,
  p_price numeric
)
RETURNS numeric AS $$
BEGIN
  RETURN p_quantity * p_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate maximum position size based on available balance
CREATE OR REPLACE FUNCTION calculate_max_position_size(
  p_available_balance numeric,
  p_price numeric,
  p_leverage integer,
  p_pair text
)
RETURNS numeric AS $$
DECLARE
  v_fee_rate numeric;
  v_max_notional numeric;
BEGIN
  -- Get taker fee (worst case)
  v_fee_rate := get_trading_fee_rate(p_pair, false);
  
  -- Max notional value = balance × leverage / (1 + fee_rate)
  v_max_notional := (p_available_balance * p_leverage) / (1 + v_fee_rate);
  
  -- Max quantity = max_notional / price
  RETURN v_max_notional / p_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate return on equity (ROE)
CREATE OR REPLACE FUNCTION calculate_roe(
  p_realized_pnl numeric,
  p_margin_allocated numeric
)
RETURNS numeric AS $$
BEGIN
  IF p_margin_allocated <= 0 THEN
    RETURN 0;
  END IF;
  
  RETURN (p_realized_pnl / p_margin_allocated) * 100;
END;
$$ LANGUAGE plpgsql STABLE;

-- Calculate distance to liquidation in percentage
CREATE OR REPLACE FUNCTION distance_to_liquidation_percent(
  p_side text,
  p_entry_price numeric,
  p_mark_price numeric,
  p_liquidation_price numeric
)
RETURNS numeric AS $$
DECLARE
  v_distance numeric;
  v_total_distance numeric;
BEGIN
  IF p_side = 'long' THEN
    v_distance := p_mark_price - p_liquidation_price;
    v_total_distance := p_entry_price - p_liquidation_price;
  ELSE -- short
    v_distance := p_liquidation_price - p_mark_price;
    v_total_distance := p_liquidation_price - p_entry_price;
  END IF;
  
  IF v_total_distance <= 0 THEN
    RETURN 0;
  END IF;
  
  RETURN (v_distance / v_total_distance) * 100;
END;
$$ LANGUAGE plpgsql STABLE;