/*
  # Add CHECK constraint to enforce USDT suffix on market_prices

  1. Changes
    - Add a CHECK constraint ensuring all pair values end with 'USDT'
    - This prevents the recreation of bare-symbol rows (e.g. 'MANA' instead of 'MANAUSDT')
    - Also update the update_market_price function to reject bare-symbol inputs

  2. Security
    - No RLS changes
*/

ALTER TABLE market_prices
  ADD CONSTRAINT market_prices_pair_usdt_suffix
  CHECK (pair LIKE '%USDT');

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
  IF p_pair NOT LIKE '%USDT' THEN
    RETURN;
  END IF;

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
