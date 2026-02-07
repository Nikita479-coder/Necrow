/*
  # Fix SOL Currency Normalization Bug

  ## Problem
  The normalize_crypto_currency function was stripping "SOL" from the end of any
  currency string, which meant pure "SOL" became an empty string "".

  This caused SOL deposits to be credited to a wallet with empty currency.

  ## Solution
  Updated the function to only strip network suffixes when they follow a base
  currency. Now it checks if the result would be empty and returns the original
  currency in that case.

  Also added specific handling for common base currencies that should not be
  stripped (SOL, MATIC, LN, AVAXC when they are the full currency name).

  ## Affected Users
  Any user who deposited SOL directly (not USDT on SOL network) would have had
  their funds credited to an empty currency wallet.
*/

CREATE OR REPLACE FUNCTION normalize_crypto_currency(p_currency text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
DECLARE
  v_upper_currency text;
  v_result text;
BEGIN
  v_upper_currency := UPPER(TRIM(p_currency));
  
  -- Handle exact matches for base currencies that could be confused with suffixes
  -- These should NOT be stripped
  IF v_upper_currency IN ('SOL', 'MATIC', 'AVAX', 'LN', 'BNB', 'ETH', 'BTC', 'USDT', 'USDC', 'XRP', 'ADA', 'DOGE', 'DOT', 'TRX', 'LTC') THEN
    RETURN v_upper_currency;
  END IF;
  
  -- Remove common network suffixes only when they follow a base currency
  v_result := REGEXP_REPLACE(
    v_upper_currency,
    '(TRC20|ERC20|BSC|BEP20|POLYGON|MATIC|SOL|ARBITRUM|OPTIMISM|AVALANCHE|LN|AVAXC)$',
    '',
    'i'
  );
  
  -- If the result is empty, return the original (trimmed, uppercased)
  -- This prevents stripping base currencies entirely
  IF v_result = '' OR v_result IS NULL THEN
    RETURN v_upper_currency;
  END IF;
  
  RETURN v_result;
END;
$function$;

-- Verify the fix works correctly
DO $$
DECLARE
  v_sol text;
  v_bnb text;
  v_usdt_sol text;
  v_usdt_trc20 text;
BEGIN
  v_sol := normalize_crypto_currency('SOL');
  v_bnb := normalize_crypto_currency('BNBBSC');
  v_usdt_sol := normalize_crypto_currency('USDTSOL');
  v_usdt_trc20 := normalize_crypto_currency('USDTTRC20');
  
  IF v_sol <> 'SOL' THEN
    RAISE EXCEPTION 'SOL normalization failed: got %', v_sol;
  END IF;
  IF v_bnb <> 'BNB' THEN
    RAISE EXCEPTION 'BNBBSC normalization failed: got %', v_bnb;
  END IF;
  IF v_usdt_sol <> 'USDT' THEN
    RAISE EXCEPTION 'USDTSOL normalization failed: got %', v_usdt_sol;
  END IF;
  IF v_usdt_trc20 <> 'USDT' THEN
    RAISE EXCEPTION 'USDTTRC20 normalization failed: got %', v_usdt_trc20;
  END IF;
  
  RAISE NOTICE 'All currency normalization tests passed';
END $$;
