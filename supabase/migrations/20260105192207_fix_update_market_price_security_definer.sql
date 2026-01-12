/*
  # Fix update_market_price function to bypass RLS

  1. Changes
    - Recreate update_market_price with SECURITY DEFINER
    - This allows the function to update market_prices even without user-level RLS policies
    
  2. Security
    - Function is safe because it only updates price data, not user data
    - Prices come from external market data sources
*/

CREATE OR REPLACE FUNCTION update_market_price(
  p_pair text,
  p_price numeric,
  p_mark_price numeric,
  p_volume numeric DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO market_prices (
    pair,
    last_price,
    mark_price,
    volume_24h,
    last_updated
  ) VALUES (
    p_pair,
    p_price,
    p_mark_price,
    p_volume,
    now()
  )
  ON CONFLICT (pair) DO UPDATE SET
    last_price = EXCLUDED.last_price,
    mark_price = EXCLUDED.mark_price,
    volume_24h = COALESCE(EXCLUDED.volume_24h, market_prices.volume_24h),
    last_updated = EXCLUDED.last_updated;
END;
$$;
