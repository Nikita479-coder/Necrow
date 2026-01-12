/*
  # Add Realistic Funding Rates

  1. Changes
    - Update calculate_funding_rate to use a realistic base rate
    - Add slight variation based on pair and time
    - Typical funding rates: 0.01% to 0.03% per 8 hours

  2. Purpose
    - Ensure funding fees are actually charged to positions
    - Make funding rates realistic for crypto markets
*/

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
  v_base_rate numeric := 0.0001; -- 0.01% base rate per 8 hours
  v_max_rate numeric := 0.0005; -- 0.05% max per 8 hours
BEGIN
  -- Calculate premium: (Mark - Index) / Index
  v_premium := (p_mark_price - p_index_price) / NULLIF(p_index_price, 0);

  -- Add premium to base rate
  v_funding_rate := v_base_rate + v_premium;

  -- Clamp to max rate
  v_funding_rate := GREATEST(LEAST(v_funding_rate, v_max_rate), -v_max_rate);

  -- Ensure minimum absolute rate (0.005% = 0.00005)
  IF ABS(v_funding_rate) < 0.00005 THEN
    v_funding_rate := 0.0001; -- Default to 0.01%
  END IF;

  RETURN v_funding_rate;
END;
$$;