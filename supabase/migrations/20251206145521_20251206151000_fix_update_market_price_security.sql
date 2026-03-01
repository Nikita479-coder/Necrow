/*
  # Fix Market Price Update Function Security

  1. Changes
    - Add SECURITY DEFINER to update_market_price function
    - This allows the function to bypass RLS and update prices from client
    
  2. Purpose
    - Fix RLS policy violations when syncing prices from frontend
    - Allow price updates to work correctly for all users
*/

-- Recreate the function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION update_market_price(
  p_pair text,
  p_price numeric,
  p_mark_price numeric DEFAULT NULL,
  p_volume numeric DEFAULT NULL
)
RETURNS boolean 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO market_prices (
    pair, last_price, mark_price, index_price, volume_24h, last_updated
  )
  VALUES (
    p_pair, p_price, COALESCE(p_mark_price, p_price), p_price, p_volume, now()
  )
  ON CONFLICT (pair) DO UPDATE
  SET last_price = EXCLUDED.last_price,
      mark_price = EXCLUDED.mark_price,
      index_price = EXCLUDED.index_price,
      volume_24h = COALESCE(EXCLUDED.volume_24h, market_prices.volume_24h),
      last_updated = now();
  
  RETURN true;
END;
$$;