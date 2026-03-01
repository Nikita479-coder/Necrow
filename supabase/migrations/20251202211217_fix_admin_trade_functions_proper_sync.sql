/*
  # Fix Admin Trade Functions for Proper Synchronization
  
  ## Changes
  1. Update open_admin_trade to properly create trader_trades entries
  2. Link admin_trader_positions to trader_trades via trader_trade_id
  3. Fix field naming (pair -> symbol)
  4. Update allocations to use percentage-based calculation
  5. Ensure close_admin_trade properly updates everything
  
  ## Functions Modified
  - open_admin_trade
  - close_admin_trade
*/

-- Recreate open_admin_trade with proper synchronization
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
  v_follower_copy_balance numeric;
  v_margin_percentage numeric;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  -- Calculate margin percentage (for followers to use same percentage)
  v_margin_percentage := (p_margin_used / 100000.0) * 100; -- Assuming 100k trader balance

  -- FIRST: Create entry in trader_trades (this is the source of truth for copy trading)
  INSERT INTO trader_trades (
    trader_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    realized_pnl,
    pnl_percentage,
    status,
    opened_at
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    0,
    0,
    'open',
    NOW()
  ) RETURNING id INTO v_trader_trade_id;

  -- SECOND: Create the position in admin_trader_positions (for admin tracking)
  INSERT INTO admin_trader_positions (
    trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    notes,
    created_by,
    opened_at,
    trader_trade_id
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    'open',
    p_notes,
    p_admin_id,
    NOW(),
    v_trader_trade_id
  ) RETURNING id INTO v_position_id;

  -- THIRD: Create allocations for all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage as follower_leverage_multiplier,
      cr.is_mock,
      cr.current_balance
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
  LOOP
    -- Get follower's copy wallet balance
    DECLARE
      v_wallet_type text;
      v_current_balance numeric;
    BEGIN
      v_wallet_type := CASE WHEN v_follower.is_mock THEN 'mock' ELSE 'copy' END;
      
      SELECT balance INTO v_current_balance
      FROM wallets
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;
      
      IF v_current_balance IS NULL THEN
        v_current_balance := 0;
      END IF;

      -- Calculate allocated amount using the same percentage as trader
      v_allocated_amount := (v_current_balance * v_margin_percentage) / 100.0;
      
      -- Only create allocation if follower has sufficient balance
      IF v_allocated_amount >= 1 AND v_current_balance >= v_allocated_amount THEN
        -- Create allocation
        INSERT INTO copy_trade_allocations (
          trader_trade_id,
          follower_id,
          copy_relationship_id,
          allocated_amount,
          follower_leverage,
          entry_price,
          status,
          source_type
        ) VALUES (
          v_trader_trade_id,
          v_follower.follower_id,
          v_follower.relationship_id,
          v_allocated_amount,
          p_leverage * v_follower.follower_leverage_multiplier,
          p_entry_price,
          'open',
          'instant'
        );
        
        -- Deduct from wallet
        UPDATE wallets
        SET 
          balance = balance - v_allocated_amount,
          updated_at = NOW()
        WHERE user_id = v_follower.follower_id
        AND currency = 'USDT'
        AND wallet_type = v_wallet_type;

        -- Update copy relationship
        UPDATE copy_relationships
        SET 
          total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
          current_balance = COALESCE(current_balance, '0')::numeric + v_allocated_amount
        WHERE id = v_follower.relationship_id;
      END IF;
    END;
  END LOOP;

  RETURN v_position_id;
END;
$$;

-- Recreate close_admin_trade with proper synchronization
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
  v_trader_trade_id uuid;
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

  -- Get the linked trader_trade_id
  v_trader_trade_id := v_position.trader_trade_id;

  -- Calculate P&L in USDT
  v_pnl_usdt := v_position.margin_used * (p_pnl_percentage / 100.0);

  -- Update admin_trader_positions
  UPDATE admin_trader_positions
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    realized_pnl = v_pnl_usdt,
    pnl_percentage = p_pnl_percentage,
    closed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_position_id;

  -- Update trader_trades
  IF v_trader_trade_id IS NOT NULL THEN
    UPDATE trader_trades
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_pnl_usdt,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_trader_trade_id;
  ELSE
    -- Fallback: find by matching criteria
    UPDATE trader_trades
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_pnl_usdt,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE trader_id = v_position.trader_id
    AND symbol = v_position.pair
    AND entry_price = v_position.entry_price
    AND status = 'open'
    AND ABS(EXTRACT(EPOCH FROM (opened_at - v_position.opened_at))) < 1
    RETURNING id INTO v_trader_trade_id;
  END IF;

  -- Distribute P&L to followers
  FOR v_allocation IN
    SELECT *
    FROM copy_trade_allocations
    WHERE trader_trade_id = v_trader_trade_id
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

    -- Return funds + P&L to follower wallet
    DECLARE
      v_wallet_type text;
      v_return_amount numeric;
    BEGIN
      -- Get wallet type from copy relationship
      SELECT 
        CASE WHEN is_mock THEN 'mock' ELSE 'copy' END
      INTO v_wallet_type
      FROM copy_relationships
      WHERE id = v_allocation.copy_relationship_id;

      v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

      -- Add back to wallet
      UPDATE wallets
      SET 
        balance = balance + v_return_amount,
        updated_at = NOW()
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;

      -- Update copy relationship cumulative PNL
      UPDATE copy_relationships
      SET 
        cumulative_pnl = COALESCE(cumulative_pnl, 0) + v_follower_pnl,
        current_balance = GREATEST(0, COALESCE(current_balance, '0')::numeric - v_allocation.allocated_amount),
        total_pnl = (COALESCE(total_pnl, '0')::numeric + v_follower_pnl)::text
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
