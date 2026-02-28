/*
  # Fix close_trader_trade - Remove Description Column
  
  ## Problem
  The transactions table doesn't have a description column, causing
  the INSERT to fail.
  
  ## Solution
  Remove the description column from the INSERT statement.
*/

CREATE OR REPLACE FUNCTION close_trader_trade(
  p_trade_id uuid,
  p_exit_price numeric,
  p_pnl_percentage numeric,
  p_admin_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade RECORD;
  v_pnl_usdt numeric;
  v_allocation RECORD;
  v_follower_pnl numeric;
  v_wallet_type text;
  v_return_amount numeric;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can close trades';
  END IF;

  -- Get trade details
  SELECT * INTO v_trade
  FROM trader_trades
  WHERE id = p_trade_id
  AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or already closed';
  END IF;

  -- Calculate P&L in USDT (with NULL safety)
  v_pnl_usdt := COALESCE(v_trade.margin_used, 0) * (COALESCE(p_pnl_percentage, 0) / 100.0);

  -- Update trader_trades
  UPDATE trader_trades
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    pnl = v_pnl_usdt,
    pnl_percent = p_pnl_percentage,
    closed_at = NOW()
  WHERE id = p_trade_id;

  -- Also update admin_trader_positions if it exists
  UPDATE admin_trader_positions
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    realized_pnl = v_pnl_usdt,
    pnl_percentage = p_pnl_percentage,
    closed_at = NOW(),
    updated_at = NOW()
  WHERE trader_trade_id = p_trade_id;

  -- Distribute P&L to all followers with allocations
  FOR v_allocation IN
    SELECT *
    FROM copy_trade_allocations
    WHERE trader_trade_id = p_trade_id
    AND status = 'open'
  LOOP
    -- Calculate follower's proportional P&L (with NULL safety)
    v_follower_pnl := COALESCE(v_allocation.allocated_amount, 0) * (COALESCE(p_pnl_percentage, 0) / 100.0);

    -- Update allocation
    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    -- Get wallet type from copy relationship
    SELECT 
      CASE WHEN is_mock THEN 'mock' ELSE 'copy' END
    INTO v_wallet_type
    FROM copy_relationships
    WHERE id = v_allocation.copy_relationship_id;

    -- Calculate return amount (with NULL safety)
    v_return_amount := COALESCE(v_allocation.allocated_amount, 0) + COALESCE(v_follower_pnl, 0);

    -- Ensure wallet exists before updating it
    PERFORM ensure_wallet(
      v_allocation.follower_id,
      'USDT',
      v_wallet_type,
      0
    );

    -- Add back to wallet (with NULL safety)
    UPDATE wallets
    SET 
      balance = COALESCE(balance, 0) + COALESCE(v_return_amount, 0),
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Update copy relationship cumulative PNL (with NULL safety)
    UPDATE copy_relationships
    SET 
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + COALESCE(v_follower_pnl, 0),
      current_balance = GREATEST(0, COALESCE(current_balance, '0')::numeric - COALESCE(v_allocation.allocated_amount, 0)),
      total_pnl = COALESCE(total_pnl, 0) + COALESCE(v_follower_pnl, 0)
    WHERE id = v_allocation.copy_relationship_id;

    -- Log transaction (without description column)
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      created_at
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_close',
      'USDT',
      COALESCE(v_return_amount, 0),
      'completed',
      NOW()
    );
  END LOOP;

  -- Update trader stats (with NULL safety)
  UPDATE admin_managed_traders
  SET 
    total_pnl = COALESCE(total_pnl, 0) + COALESCE(v_pnl_usdt, 0),
    updated_at = NOW()
  WHERE id = v_trade.trader_id;
END;
$$;
