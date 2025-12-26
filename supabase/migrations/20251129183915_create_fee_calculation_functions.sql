/*
  # Fee Calculation Functions

  1. Functions
    - `get_user_fee_rates` - Get maker/taker rates for user based on VIP level
    - `calculate_spread_cost` - Calculate spread markup cost
    - `calculate_trading_fee` - Calculate maker/taker fee on position
    - `calculate_funding_rate` - Calculate current funding rate for pair
    - `apply_funding_payment` - Apply funding payment to position holders
    - `calculate_liquidation_fee` - Calculate and distribute liquidation fee
    - `get_effective_entry_price` - Get entry price including spread markup

  2. Purpose
    - Centralize all fee calculations
    - Ensure consistency across the platform
    - Track all fees in fee_collections table
*/

-- Get user's fee rates based on VIP level
CREATE OR REPLACE FUNCTION get_user_fee_rates(p_user_id uuid)
RETURNS TABLE(maker_fee numeric, taker_fee numeric, vip_level integer)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_vip_level integer := 1;
BEGIN
  -- Get user's VIP level
  SELECT COALESCE(rs.vip_level, 1)
  INTO v_vip_level
  FROM referral_stats rs
  WHERE rs.user_id = p_user_id;

  -- Return fee rates for this VIP level
  RETURN QUERY
  SELECT 
    tft.maker_fee_rate,
    tft.taker_fee_rate,
    tft.vip_level
  FROM trading_fee_tiers tft
  WHERE tft.vip_level = v_vip_level;
END;
$$;

-- Calculate spread cost (artificial markup added to market spread)
CREATE OR REPLACE FUNCTION calculate_spread_cost(
  p_pair text,
  p_entry_price numeric,
  p_quantity numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_spread_markup numeric := 0;
  v_notional numeric;
  v_spread_cost numeric;
BEGIN
  -- Get spread markup for this pair
  SELECT COALESCE(spread_markup_percent, 0.0001)
  INTO v_spread_markup
  FROM spread_config
  WHERE pair = p_pair AND is_active = true;

  -- Calculate notional size
  v_notional := p_entry_price * p_quantity;

  -- Calculate spread cost
  v_spread_cost := v_notional * v_spread_markup;

  RETURN v_spread_cost;
END;
$$;

-- Get effective entry price including spread markup
CREATE OR REPLACE FUNCTION get_effective_entry_price(
  p_pair text,
  p_market_price numeric,
  p_side text
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_spread_markup numeric := 0;
  v_effective_price numeric;
BEGIN
  -- Get spread markup for this pair
  SELECT COALESCE(spread_markup_percent, 0.0001)
  INTO v_spread_markup
  FROM spread_config
  WHERE pair = p_pair AND is_active = true;

  -- Apply spread markup based on side
  IF p_side = 'long' THEN
    -- Buying: pay higher (ask price)
    v_effective_price := p_market_price * (1 + v_spread_markup);
  ELSE
    -- Selling: receive lower (bid price)
    v_effective_price := p_market_price * (1 - v_spread_markup);
  END IF;

  RETURN v_effective_price;
END;
$$;

-- Calculate trading fee (maker or taker)
CREATE OR REPLACE FUNCTION calculate_trading_fee(
  p_user_id uuid,
  p_notional_size numeric,
  p_is_maker boolean
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fee_rate numeric;
  v_fee_amount numeric;
BEGIN
  -- Get user's fee rate
  IF p_is_maker THEN
    SELECT maker_fee INTO v_fee_rate
    FROM get_user_fee_rates(p_user_id);
  ELSE
    SELECT taker_fee INTO v_fee_rate
    FROM get_user_fee_rates(p_user_id);
  END IF;

  -- Calculate fee (can be negative for maker rebates)
  v_fee_amount := p_notional_size * v_fee_rate;

  RETURN v_fee_amount;
END;
$$;

-- Calculate current funding rate for a pair
CREATE OR REPLACE FUNCTION calculate_funding_rate(
  p_pair text,
  p_mark_price numeric,
  p_index_price numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_premium numeric;
  v_funding_rate numeric;
  v_max_rate numeric := 0.0005; -- 0.05% max per 8 hours
BEGIN
  -- Calculate premium: (Mark - Index) / Index
  v_premium := (p_mark_price - p_index_price) / p_index_price;

  -- Clamp to max rate
  v_funding_rate := GREATEST(LEAST(v_premium, v_max_rate), -v_max_rate);

  RETURN v_funding_rate;
END;
$$;

-- Apply funding payment to all open positions for a pair
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

  -- For now, assume index price = mark price (should be from external feed)
  v_index_price := v_mark_price;

  -- Calculate funding rate
  v_funding_rate := calculate_funding_rate(p_pair, v_mark_price, v_index_price);

  -- Store funding rate
  INSERT INTO funding_rates (
    pair,
    funding_rate,
    mark_price,
    index_price,
    funding_timestamp,
    next_funding_time
  ) VALUES (
    p_pair,
    v_funding_rate,
    v_mark_price,
    v_index_price,
    NOW(),
    NOW() + INTERVAL '8 hours'
  );

  -- Apply to all open positions for this pair
  FOR v_position_record IN
    SELECT 
      position_id,
      user_id,
      side,
      quantity,
      entry_price
    FROM futures_positions
    WHERE pair = p_pair AND status = 'open'
  LOOP
    -- Calculate notional size
    v_notional_size := v_position_record.quantity * v_position_record.entry_price;

    -- Calculate payment (positive = user pays, negative = user receives)
    IF v_position_record.side = 'long' THEN
      v_payment_amount := v_notional_size * v_funding_rate;
    ELSE
      v_payment_amount := -v_notional_size * v_funding_rate;
    END IF;

    -- Record funding payment
    INSERT INTO funding_payments (
      user_id,
      position_id,
      pair,
      funding_rate,
      position_size,
      payment_amount,
      is_paid,
      funding_timestamp
    ) VALUES (
      v_position_record.user_id,
      v_position_record.position_id,
      p_pair,
      v_funding_rate,
      v_notional_size,
      v_payment_amount,
      false,
      NOW()
    );

    -- Deduct/credit from unrealized PnL (doesn't affect margin immediately)
    UPDATE futures_positions
    SET unrealized_pnl = unrealized_pnl - v_payment_amount
    WHERE position_id = v_position_record.position_id;
  END LOOP;
END;
$$;

-- Calculate and apply liquidation fee
CREATE OR REPLACE FUNCTION calculate_liquidation_fee(
  p_user_id uuid,
  p_position_id uuid,
  p_notional_size numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_liquidation_fee_rate numeric;
  v_insurance_split numeric;
  v_exchange_split numeric;
  v_total_fee numeric;
  v_insurance_amount numeric;
  v_exchange_amount numeric;
BEGIN
  -- Get liquidation config
  SELECT 
    liquidation_fee_rate,
    insurance_fund_split,
    exchange_revenue_split
  INTO 
    v_liquidation_fee_rate,
    v_insurance_split,
    v_exchange_split
  FROM liquidation_config
  ORDER BY created_at DESC
  LIMIT 1;

  -- Calculate total liquidation fee
  v_total_fee := p_notional_size * v_liquidation_fee_rate;

  -- Split between insurance fund and exchange
  v_insurance_amount := v_total_fee * v_insurance_split;
  v_exchange_amount := v_total_fee * v_exchange_split;

  -- Add to insurance fund
  UPDATE insurance_fund
  SET 
    balance = balance + v_insurance_amount,
    last_updated = NOW()
  WHERE currency = 'USDT';

  -- Record fee collection (insurance portion)
  INSERT INTO fee_collections (
    user_id,
    position_id,
    fee_type,
    pair,
    notional_size,
    fee_rate,
    fee_amount,
    metadata
  )
  SELECT
    p_user_id,
    p_position_id,
    'liquidation',
    fp.pair,
    p_notional_size,
    v_liquidation_fee_rate,
    v_insurance_amount,
    jsonb_build_object('destination', 'insurance_fund', 'split', v_insurance_split)
  FROM futures_positions fp
  WHERE fp.position_id = p_position_id;

  -- Record fee collection (exchange portion)
  INSERT INTO fee_collections (
    user_id,
    position_id,
    fee_type,
    pair,
    notional_size,
    fee_rate,
    fee_amount,
    metadata
  )
  SELECT
    p_user_id,
    p_position_id,
    'liquidation',
    fp.pair,
    p_notional_size,
    v_liquidation_fee_rate,
    v_exchange_amount,
    jsonb_build_object('destination', 'exchange_revenue', 'split', v_exchange_split)
  FROM futures_positions fp
  WHERE fp.position_id = p_position_id;

  RETURN v_total_fee;
END;
$$;

-- Record trading fee collection
CREATE OR REPLACE FUNCTION record_trading_fee(
  p_user_id uuid,
  p_position_id uuid,
  p_pair text,
  p_notional_size numeric,
  p_is_maker boolean
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fee_amount numeric;
  v_fee_rate numeric;
  v_fee_type text;
BEGIN
  -- Calculate fee
  v_fee_amount := calculate_trading_fee(p_user_id, p_notional_size, p_is_maker);

  -- Get fee rate
  IF p_is_maker THEN
    SELECT maker_fee INTO v_fee_rate FROM get_user_fee_rates(p_user_id);
    v_fee_type := 'maker';
  ELSE
    SELECT taker_fee INTO v_fee_rate FROM get_user_fee_rates(p_user_id);
    v_fee_type := 'taker';
  END IF;

  -- Record fee collection
  INSERT INTO fee_collections (
    user_id,
    position_id,
    fee_type,
    pair,
    notional_size,
    fee_rate,
    fee_amount
  ) VALUES (
    p_user_id,
    p_position_id,
    v_fee_type,
    p_pair,
    p_notional_size,
    v_fee_rate,
    v_fee_amount
  );

  RETURN v_fee_amount;
END;
$$;
