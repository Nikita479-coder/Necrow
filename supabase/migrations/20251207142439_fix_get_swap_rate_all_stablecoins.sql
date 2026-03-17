/*
  # Fix get_swap_rate to support all stablecoins
  
  1. Updates
    - Updates get_swap_rate function to recognize all stablecoins (USDT, USDC, DAI, BUSD, TUSD, USDP, GUSD)
    - Ensures consistent 1:1 rate between all stablecoins
    - Matches frontend stablecoin logic
*/

CREATE OR REPLACE FUNCTION get_swap_rate(p_from_currency text, p_to_currency text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_from_price numeric;
  v_to_price numeric;
  v_stablecoins text[] := ARRAY['USDT', 'USDC', 'DAI', 'BUSD', 'TUSD', 'USDP', 'GUSD'];
BEGIN
  -- Handle stablecoins first
  IF p_from_currency = ANY(v_stablecoins) THEN
    v_from_price := 1.0;
  ELSE
    -- Get current price from market_prices (in USDT)
    SELECT mark_price INTO v_from_price
    FROM market_prices
    WHERE pair = p_from_currency || 'USDT'
    LIMIT 1;
  END IF;

  IF p_to_currency = ANY(v_stablecoins) THEN
    v_to_price := 1.0;
  ELSE
    -- Get current price from market_prices (in USDT)
    SELECT mark_price INTO v_to_price
    FROM market_prices
    WHERE pair = p_to_currency || 'USDT'
    LIMIT 1;
  END IF;

  -- If prices not found, return 0
  IF v_from_price IS NULL OR v_to_price IS NULL THEN
    RETURN 0;
  END IF;

  -- Calculate rate: how many to_currency per 1 from_currency
  RETURN v_from_price / v_to_price;
END;
$$;
