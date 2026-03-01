/*
  # Fix Admin Trade Functions for Percentage-Based Copy Trading

  1. New Functions
    - `open_admin_trade`: Opens trade for admin trader and creates allocations for followers based on their copy wallet balance percentage
    - `close_admin_trade`: Closes trade and distributes PNL to followers proportionally

  2. Logic
    - When opening: For each follower, calculate allocation = (copy_wallet_balance * allocation_percentage / 100)
    - When closing: Calculate PNL for each allocation and credit to copy wallet
    - Create proper transaction records for tracking

  3. Security
    - Only admins can execute these functions
    - All operations are atomic with proper error handling
*/

-- Function to open admin trade and create follower allocations
CREATE OR REPLACE FUNCTION open_admin_trade(
  p_trader_id UUID,
  p_pair TEXT,
  p_side TEXT,
  p_entry_price NUMERIC,
  p_margin_used NUMERIC,
  p_leverage INTEGER,
  p_is_mock BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_position_id UUID;
  v_trader_trade_id UUID;
  v_quantity NUMERIC;
  v_follower RECORD;
  v_follower_wallet_balance NUMERIC;
  v_follower_allocation NUMERIC;
  v_allocation_id UUID;
  v_result JSON;
BEGIN
  -- Check if user is admin
  IF (SELECT COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false)) = false THEN
    RAISE EXCEPTION 'Only admins can open trades';
  END IF;

  -- Calculate quantity based on margin and leverage
  v_quantity := (p_margin_used * p_leverage) / p_entry_price;

  -- Create admin trader position
  INSERT INTO admin_trader_positions (
    trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    status,
    is_mock
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    v_quantity,
    p_leverage,
    p_margin_used,
    'open',
    p_is_mock
  ) RETURNING id INTO v_admin_position_id;

  -- Create corresponding trader_trade record
  INSERT INTO trader_trades (
    trader_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    status,
    is_mock
  ) VALUES (
    p_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    v_quantity,
    p_leverage,
    'open',
    p_is_mock
  ) RETURNING id INTO v_trader_trade_id;

  -- Create allocations for all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage as follower_leverage,
      cr.is_mock as relationship_is_mock
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_mock = p_is_mock
  LOOP
    -- Get follower's copy wallet balance
    SELECT COALESCE(balance, 0) INTO v_follower_wallet_balance
    FROM wallets
    WHERE user_id = v_follower.follower_id
    AND currency = 'USDT'
    AND wallet_type = 'copy';

    -- Calculate allocation based on percentage
    v_follower_allocation := (v_follower_wallet_balance * v_follower.allocation_percentage) / 100.0;

    -- Only create allocation if follower has sufficient balance
    IF v_follower_allocation >= 10 THEN
      -- Lock the allocated amount in follower's copy wallet
      UPDATE wallets
      SET locked_balance = locked_balance + v_follower_allocation,
          balance = balance - v_follower_allocation,
          updated_at = NOW()
      WHERE user_id = v_follower.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

      -- Create allocation record
      INSERT INTO copy_trade_allocations (
        trader_trade_id,
        follower_id,
        copy_relationship_id,
        allocated_amount,
        follower_leverage,
        entry_price,
        status
      ) VALUES (
        v_trader_trade_id,
        v_follower.follower_id,
        v_follower.relationship_id,
        v_follower_allocation,
        v_follower.follower_leverage,
        p_entry_price,
        'open'
      ) RETURNING id INTO v_allocation_id;
    END IF;
  END LOOP;

  v_result := json_build_object(
    'position_id', v_admin_position_id,
    'trader_trade_id', v_trader_trade_id,
    'success', true
  );

  RETURN v_result;
END;
$$;

-- Function to close admin trade and distribute PNL
CREATE OR REPLACE FUNCTION close_admin_trade(
  p_position_id UUID,
  p_exit_price NUMERIC,
  p_realized_pnl NUMERIC
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_position RECORD;
  v_trader_trade_id UUID;
  v_pnl_percentage NUMERIC;
  v_allocation RECORD;
  v_follower_pnl NUMERIC;
  v_follower_final_amount NUMERIC;
  v_result JSON;
BEGIN
  -- Check if user is admin
  IF (SELECT COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false)) = false THEN
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

  -- Calculate PNL percentage
  v_pnl_percentage := (p_realized_pnl / v_position.margin_used) * 100;

  -- Update admin position
  UPDATE admin_trader_positions
  SET 
    exit_price = p_exit_price,
    realized_pnl = p_realized_pnl,
    pnl_percentage = v_pnl_percentage,
    status = 'closed',
    closed_at = NOW()
  WHERE id = p_position_id;

  -- Get corresponding trader_trade_id
  SELECT id INTO v_trader_trade_id
  FROM trader_trades
  WHERE trader_id = v_position.trader_id
  AND symbol = v_position.pair
  AND entry_price = v_position.entry_price
  AND status = 'open'
  AND is_mock = v_position.is_mock
  ORDER BY opened_at DESC
  LIMIT 1;

  -- Update trader_trade
  IF v_trader_trade_id IS NOT NULL THEN
    UPDATE trader_trades
    SET 
      exit_price = p_exit_price,
      pnl = p_realized_pnl,
      pnl_percent = v_pnl_percentage,
      status = 'closed',
      closed_at = NOW()
    WHERE id = v_trader_trade_id;

    -- Process all allocations for this trade
    FOR v_allocation IN
      SELECT *
      FROM copy_trade_allocations
      WHERE trader_trade_id = v_trader_trade_id
      AND status = 'open'
    LOOP
      -- Calculate follower's PNL based on their allocation
      v_follower_pnl := v_allocation.allocated_amount * (v_pnl_percentage / 100);
      v_follower_final_amount := v_allocation.allocated_amount + v_follower_pnl;

      -- Update allocation record
      UPDATE copy_trade_allocations
      SET 
        exit_price = p_exit_price,
        realized_pnl = v_follower_pnl,
        pnl_percentage = v_pnl_percentage,
        status = 'closed',
        closed_at = NOW()
      WHERE id = v_allocation.id;

      -- Unlock and credit final amount to follower's copy wallet
      UPDATE wallets
      SET 
        locked_balance = locked_balance - v_allocation.allocated_amount,
        balance = balance + v_follower_final_amount,
        updated_at = NOW()
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

      -- Create transaction record
      INSERT INTO transactions (
        user_id,
        transaction_type,
        currency,
        amount,
        status,
        created_at
      ) VALUES (
        v_allocation.follower_id,
        'transfer',
        'USDT',
        v_follower_pnl,
        'completed',
        NOW()
      );
    END LOOP;
  END IF;

  v_result := json_build_object(
    'position_id', p_position_id,
    'trader_trade_id', v_trader_trade_id,
    'pnl_percentage', v_pnl_percentage,
    'success', true
  );

  RETURN v_result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION open_admin_trade TO authenticated;
GRANT EXECUTE ON FUNCTION close_admin_trade TO authenticated;
