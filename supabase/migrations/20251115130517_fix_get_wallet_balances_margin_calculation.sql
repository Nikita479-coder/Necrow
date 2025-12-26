/*
  # Fix Wallet Balance Function - Correct Margin Calculation

  ## Description
  Updates the `get_wallet_balances` function to calculate the actual margin in use
  from open positions instead of using the `locked_balance` field which stores
  the notional value multiplied by leverage.

  ## Changes
  1. Calculate `futures_locked` as the sum of `margin_allocated` from all open positions
  2. This ensures "Margin in Use" shows the actual margin (e.g., $52.32) not the
     notional value (e.g., $6,571.33)

  ## Notes
  - Margin in use = sum of margin_allocated from futures_positions where status = 'open'
  - Total futures balance = available_balance + actual margin in use
*/

CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_main_balance numeric;
  v_futures_available numeric;
  v_futures_locked numeric;
BEGIN
  -- Get main wallet balance
  SELECT balance INTO v_main_balance
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT';

  -- Get futures available balance
  SELECT available_balance
  INTO v_futures_available
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  -- Calculate actual margin in use from open positions
  SELECT COALESCE(SUM(margin_allocated), 0)
  INTO v_futures_locked
  FROM futures_positions
  WHERE user_id = p_user_id AND status = 'open';

  RETURN jsonb_build_object(
    'main_wallet', COALESCE(v_main_balance, 0),
    'futures_available', COALESCE(v_futures_available, 0),
    'futures_locked', v_futures_locked,
    'futures_total', COALESCE(v_futures_available, 0) + v_futures_locked
  );
END;
$$ LANGUAGE plpgsql STABLE;
