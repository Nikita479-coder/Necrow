/*
  # Fix Close Trader Trade - Variable Scope Issue
  
  ## Changes
  Fixes the variable scope issue by declaring v_actual_pnl_percentage
  at the function level instead of inside a nested DECLARE block.
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
  v_position_size numeric;
  v_price_diff numeric;
  v_follower_leverage integer;
  v_actual_pnl_percentage numeric;
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

  -- Calculate P&L in USDT for the trader
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
    SELECT 
      cta.*,
      cr.leverage as follower_leverage,
      cr.is_mock
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cta.copy_relationship_id = cr.id
    WHERE cta.trader_trade_id = p_trade_id
    AND cta.status = 'open'
  LOOP
    -- Get follower's leverage from the copy relationship
    v_follower_leverage := COALESCE(v_allocation.follower_leverage, 1);
    
    -- Calculate position size: (allocated_amount * leverage) / entry_price
    v_position_size := (COALESCE(v_allocation.allocated_amount, 0) * v_follower_leverage) / NULLIF(COALESCE(v_allocation.entry_price, 1), 0);
    
    -- Calculate price difference based on side
    IF v_allocation.side = 'long' THEN
      -- For long: profit when price goes up
      v_price_diff := COALESCE(p_exit_price, 0) - COALESCE(v_allocation.entry_price, 0);
    ELSE
      -- For short: profit when price goes down
      v_price_diff := COALESCE(v_allocation.entry_price, 0) - COALESCE(p_exit_price, 0);
    END IF;
    
    -- Calculate follower's actual P&L
    v_follower_pnl := v_position_size * v_price_diff;
    
    -- Calculate PNL percentage: (PNL / allocated_amount) * 100
    IF v_allocation.allocated_amount > 0 THEN
      v_actual_pnl_percentage := (v_follower_pnl / v_allocation.allocated_amount) * 100;
    ELSE
      v_actual_pnl_percentage := 0;
    END IF;

    -- Update allocation
    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = v_actual_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    -- Get wallet type
    v_wallet_type := CASE WHEN v_allocation.is_mock THEN 'mock' ELSE 'copy' END;

    -- Calculate return amount: allocated_amount + PNL
    v_return_amount := COALESCE(v_allocation.allocated_amount, 0) + COALESCE(v_follower_pnl, 0);

    -- Ensure wallet exists
    PERFORM ensure_wallet(
      v_allocation.follower_id,
      'USDT',
      v_wallet_type,
      0
    );

    -- Return funds to wallet
    UPDATE wallets
    SET 
      balance = COALESCE(balance, 0) + COALESCE(v_return_amount, 0),
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Update copy relationship balances
    UPDATE copy_relationships
    SET 
      -- Add PNL to cumulative_pnl
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + COALESCE(v_follower_pnl, 0),
      -- Update current_balance: add back allocated amount + PNL
      current_balance = COALESCE(current_balance, 0) + COALESCE(v_return_amount, 0),
      -- Update total_pnl
      total_pnl = COALESCE(total_pnl, 0) + COALESCE(v_follower_pnl, 0),
      updated_at = NOW()
    WHERE id = v_allocation.copy_relationship_id;

    -- Log transaction
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

  -- Update trader stats
  UPDATE admin_managed_traders
  SET 
    total_pnl = COALESCE(total_pnl, 0) + COALESCE(v_pnl_usdt, 0),
    updated_at = NOW()
  WHERE id = v_trade.trader_id;
END;
$$;
