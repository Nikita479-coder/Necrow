/*
  # Fix close_trader_trade - Ensure Wallet Exists
  
  ## Problem
  The close_trader_trade function tries to UPDATE a wallet that might not exist,
  causing NULL constraint violations when the wallet needs to be created.
  
  ## Solution
  Use the ensure_wallet() helper function to create wallets before updating them.
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

  -- Calculate P&L in USDT
  v_pnl_usdt := v_trade.margin_used * (p_pnl_percentage / 100.0);

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
    -- Calculate follower's proportional P&L
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);

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

    v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

    -- Ensure wallet exists before updating it
    PERFORM ensure_wallet(
      v_allocation.follower_id,
      'USDT',
      v_wallet_type,
      0
    );

    -- Add back to wallet
    UPDATE wallets
    SET 
      balance = COALESCE(balance, 0) + v_return_amount,
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Update copy relationship cumulative PNL
    UPDATE copy_relationships
    SET 
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + v_follower_pnl,
      current_balance = GREATEST(0, COALESCE(current_balance, '0')::numeric - v_allocation.allocated_amount),
      total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl
    WHERE id = v_allocation.copy_relationship_id;

    -- Log transaction
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      description,
      created_at
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_close',
      'USDT',
      v_return_amount,
      'completed',
      'Copy trade closed: ' || v_trade.symbol,
      NOW()
    );
  END LOOP;

  -- Update trader stats
  UPDATE admin_managed_traders
  SET 
    total_pnl = COALESCE(total_pnl, 0) + v_pnl_usdt,
    updated_at = NOW()
  WHERE id = v_trade.trader_id;
END;
$$;
