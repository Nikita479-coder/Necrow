/*
  # Fix market_prices volume precision for high-volume tokens
  
  1. Changes
    - Increase volume_24h precision to handle large volumes (like PEPE)
    - Change from numeric(20,8) to numeric(30,2) for volume
    - 30 total digits, 2 decimal places = max value up to 10^28
  
  2. Notes
    - This fixes the overflow error for tokens with very high trading volumes
    - Volume doesn't need 8 decimal places precision
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS update_market_price(text, numeric, numeric, numeric);

-- Update volume_24h column to support larger values
ALTER TABLE market_prices 
  ALTER COLUMN volume_24h TYPE numeric(30,2);

-- Recreate the update_market_price function with updated parameter type
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