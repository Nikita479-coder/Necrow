/*
  # Create Total Portfolio Value Calculation Function
  
  1. New Function
    - `calculate_total_portfolio_value_usd(user_id)` - Returns total USD value of all holdings
    - Converts all crypto holdings to USD using market_prices
    - Includes: main wallet, assets wallet, copy wallet, futures wallet
  
  2. How it works
    - For each currency in wallets, multiply balance by current price from market_prices
    - USDT is already in USD (1:1)
    - Add futures wallet balance (already in USDT)
    - Returns total portfolio value in USD
*/

CREATE OR REPLACE FUNCTION calculate_total_portfolio_value_usd(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_total_value numeric := 0;
  v_wallet_value numeric;
  v_futures_value numeric;
BEGIN
  -- Calculate value from all spot wallets (main, assets, copy)
  SELECT COALESCE(SUM(
    CASE 
      WHEN w.currency = 'USDT' THEN w.balance::numeric
      ELSE w.balance::numeric * COALESCE(mp.last_price::numeric, 0)
    END
  ), 0)
  INTO v_wallet_value
  FROM wallets w
  LEFT JOIN market_prices mp ON mp.pair = w.currency || 'USDT'
  WHERE w.user_id = p_user_id;
  
  -- Add futures wallet (already in USDT)
  SELECT COALESCE(available_balance::numeric + locked_balance::numeric, 0)
  INTO v_futures_value
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;
  
  v_total_value := v_wallet_value + v_futures_value;
  
  RETURN v_total_value;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_total_portfolio_value_usd(uuid) TO authenticated;
