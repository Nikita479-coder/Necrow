/*
  # Sync Admin Trades to trader_trades Table
  
  1. Changes
    - Update open_admin_trade to also insert into trader_trades table
    - Update close_admin_trade to also update trader_trades table
    - This ensures admin-managed trader positions show up on copy trading pages
  
  2. Purpose
    - When admin opens a trade for a managed trader, it needs to be visible in trader_trades
    - This allows followers to see the trader's positions on the ActiveCopyTrading page
*/

-- Update open_admin_trade to also create trader_trades entry
CREATE OR REPLACE FUNCTION open_admin_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text,
  p_admin_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position_id uuid;
  v_trader_trade_id uuid;
  v_follower RECORD;
  v_allocated_amount numeric;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  -- Create the position in admin_trader_positions
  INSERT INTO admin_trader_positions (
    trader_id, pair, side, entry_price, quantity, leverage, margin_used,
    status, notes, created_by, opened_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage, p_margin_used,
    'open', p_notes, p_admin_id, NOW()
  ) RETURNING id INTO v_position_id;

  -- ALSO create entry in trader_trades for copy trading visibility
  INSERT INTO trader_trades (
    trader_id, symbol, side, entry_price, quantity, leverage,
    pnl, pnl_percent, status, opened_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage,
    0, 0, 'open', NOW()
  ) RETURNING id INTO v_trader_trade_id;

  -- Create allocations for all followers of this admin trader
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.copy_amount,
      cr.leverage as follower_leverage,
      cr.is_mock
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
  LOOP
    -- Calculate allocation (proportional to margin used)
    v_allocated_amount := v_follower.copy_amount * (p_margin_used / 1000.0);
    
    IF v_allocated_amount >= 1 THEN
      -- Check follower has sufficient balance
      DECLARE
        v_wallet_type text;
        v_current_balance numeric;
      BEGIN
        v_wallet_type := CASE WHEN v_follower.is_mock THEN 'mock' ELSE 'spot' END;
        
        SELECT balance INTO v_current_balance
        FROM wallets
        WHERE user_id = v_follower.follower_id
        AND currency = 'USDT'
        AND wallet_type = v_wallet_type;
        
        IF v_current_balance IS NOT NULL AND v_current_balance >= v_allocated_amount THEN
          -- Create allocation (use trader_trade_id so it links to trader_trades)
          INSERT INTO copy_trade_allocations (
            trader_trade_id, follower_id, copy_relationship_id,
            allocated_amount, follower_leverage, entry_price, status
          ) VALUES (
            v_trader_trade_id, v_follower.follower_id, v_follower.relationship_id,
            v_allocated_amount, p_leverage * v_follower.follower_leverage, p_entry_price, 'open'
          );
          
          -- Deduct from wallet
          UPDATE wallets
          SET balance = balance - v_allocated_amount,
              updated_at = NOW()
          WHERE user_id = v_follower.follower_id
          AND currency = 'USDT'
          AND wallet_type = v_wallet_type;
        END IF;
      END;
    END IF;
  END LOOP;

  RETURN v_position_id;
END;
$$;

-- Update close_admin_trade to also update trader_trades
CREATE OR REPLACE FUNCTION close_admin_trade(
  p_position_id uuid,
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
  v_position RECORD;
  v_pnl_usdt numeric;
  v_allocation RECORD;
  v_follower_pnl numeric;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can close trades';
  END IF;

  -- Get position details
  SELECT * INTO v_position
  FROM admin_trader_positions
  WHERE id = p_position_id
  AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Position not found or already closed';
  END IF;

  -- Calculate P&L in USDT
  v_pnl_usdt := v_position.margin_used * (p_pnl_percentage / 100.0);

  -- Update admin_trader_positions
  UPDATE admin_trader_positions
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    realized_pnl = v_pnl_usdt,
    pnl_percentage = p_pnl_percentage,
    closed_at = NOW()
  WHERE id = p_position_id;

  -- ALSO update trader_trades
  UPDATE trader_trades
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    pnl = v_pnl_usdt,
    pnl_percent = p_pnl_percentage,
    closed_at = NOW()
  WHERE trader_id = v_position.trader_id
  AND symbol = v_position.pair
  AND entry_price = v_position.entry_price
  AND status = 'open'
  AND opened_at = v_position.opened_at;

  -- Distribute P&L to followers
  FOR v_allocation IN
    SELECT *
    FROM copy_trade_allocations
    WHERE trader_trade_id IN (
      SELECT id FROM trader_trades 
      WHERE trader_id = v_position.trader_id 
      AND symbol = v_position.pair
      AND closed_at = NOW()
    )
    AND status = 'open'
  LOOP
    -- Calculate follower's proportional P&L
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);

    -- Update allocation
    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW()
    WHERE id = v_allocation.id;

    -- Return funds + P&L to follower wallet
    DECLARE
      v_wallet_type text;
      v_return_amount numeric;
    BEGIN
      -- Get wallet type from copy relationship
      SELECT 
        CASE WHEN is_mock THEN 'mock' ELSE 'spot' END
      INTO v_wallet_type
      FROM copy_relationships
      WHERE id = v_allocation.copy_relationship_id;

      v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

      -- Add back to wallet
      UPDATE wallets
      SET balance = balance + v_return_amount,
          updated_at = NOW()
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;

      -- Log transaction
      INSERT INTO transactions (
        user_id, type, currency, amount, status,
        description, created_at
      ) VALUES (
        v_allocation.follower_id,
        'copy_trade_close',
        'USDT',
        v_return_amount,
        'completed',
        format('Copy trade closed: %s %s at %s. P&L: %s USDT (%s%%)', 
          v_position.side, v_position.pair, p_exit_price, 
          v_follower_pnl, p_pnl_percentage),
        NOW()
      );
    END;
  END LOOP;

  -- Update trader stats
  UPDATE admin_managed_traders
  SET 
    total_pnl = COALESCE(total_pnl, 0) + v_pnl_usdt,
    updated_at = NOW()
  WHERE id = v_position.trader_id;
END;
$$;
