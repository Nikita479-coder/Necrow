/*
  # Fix Mock Wallet Initial Balance

  ## Problem
  When a user first accesses mock trading, the wallet shows 0 instead of 10,000 USDT.

  ## Solution
  Update the get_mock_trading_summary function to properly create wallet with
  10,000 USDT default and return correct initial values.
*/

-- Recreate the function with proper initial balance handling
CREATE OR REPLACE FUNCTION get_mock_trading_summary()
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_wallet mock_wallets;
  v_open_positions integer;
  v_total_margin numeric;
  v_total_trades integer;
  v_winning_trades integer;
  v_total_pnl numeric;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Get or create wallet with explicit 10000 default
  SELECT * INTO v_wallet FROM mock_wallets WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    INSERT INTO mock_wallets (user_id, balance, locked_balance)
    VALUES (v_user_id, 10000.00, 0.00)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING * INTO v_wallet;
    
    -- If still not found (race condition), try select again
    IF v_wallet IS NULL THEN
      SELECT * INTO v_wallet FROM mock_wallets WHERE user_id = v_user_id;
    END IF;
    
    -- If still NULL, use defaults
    IF v_wallet IS NULL THEN
      v_wallet.balance := 10000.00;
      v_wallet.locked_balance := 0.00;
    END IF;
  END IF;

  -- Count open positions
  SELECT COUNT(*), COALESCE(SUM(margin_allocated), 0)
  INTO v_open_positions, v_total_margin
  FROM mock_futures_positions
  WHERE user_id = v_user_id AND status = 'open';

  -- Count total closed trades and winning trades
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE realized_pnl > 0),
    COALESCE(SUM(realized_pnl), 0)
  INTO v_total_trades, v_winning_trades, v_total_pnl
  FROM mock_futures_positions
  WHERE user_id = v_user_id AND status IN ('closed', 'liquidated');

  RETURN jsonb_build_object(
    'success', true,
    'wallet', jsonb_build_object(
      'balance', COALESCE(v_wallet.balance, 10000.00),
      'locked_balance', COALESCE(v_wallet.locked_balance, 0.00),
      'total_equity', COALESCE(v_wallet.balance, 10000.00) + COALESCE(v_wallet.locked_balance, 0.00)
    ),
    'positions', jsonb_build_object(
      'open_count', COALESCE(v_open_positions, 0),
      'total_margin', COALESCE(v_total_margin, 0)
    ),
    'performance', jsonb_build_object(
      'total_trades', COALESCE(v_total_trades, 0),
      'winning_trades', COALESCE(v_winning_trades, 0),
      'win_rate', CASE WHEN COALESCE(v_total_trades, 0) > 0 
        THEN round((COALESCE(v_winning_trades, 0)::numeric / v_total_trades) * 100, 2) 
        ELSE 0 
      END,
      'total_pnl', COALESCE(v_total_pnl, 0),
      'roi', round(((COALESCE(v_wallet.balance, 10000.00) + COALESCE(v_wallet.locked_balance, 0.00) - 10000) / 10000) * 100, 2)
    )
  );
END;
$$;
