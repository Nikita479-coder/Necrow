/*
  # Fix Duplicate Cumulative PNL Update

  ## Problem
  - cumulative_pnl is being updated twice when a trade closes
  - Once by the trigger `update_cumulative_pnl_on_allocation_close`
  - Once by the `close_trader_trade` function manually
  - This causes cumulative_pnl to be double what it should be

  ## Solution
  - Remove the manual cumulative_pnl update from close_trader_trade function
  - Let the trigger handle it automatically when allocation status changes to closed
  - Update current_balance calculation to use realized_pnl from the allocation

  ## Impact
  - Future trade closes will correctly update cumulative_pnl only once
  - Existing incorrect data must be manually fixed
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
  v_return_amount numeric;
  v_wallet_type text;
  v_current_wallet_balance numeric;
  v_commission_result jsonb;
BEGIN
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can close trades';
  END IF;

  IF p_exit_price IS NULL OR p_exit_price <= 0 THEN
    RAISE EXCEPTION 'Exit price is required and must be greater than 0';
  END IF;

  IF p_pnl_percentage IS NULL THEN
    RAISE EXCEPTION 'PNL percentage is required';
  END IF;

  SELECT * INTO v_trade
  FROM trader_trades
  WHERE id = p_trade_id
  AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or already closed';
  END IF;

  v_pnl_usdt := COALESCE(v_trade.margin_used, 0) * (p_pnl_percentage / 100.0);

  UPDATE trader_trades
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    pnl = v_pnl_usdt,
    pnl_percent = p_pnl_percentage,
    closed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  FOR v_allocation IN
    SELECT 
      cta.*,
      cr.is_mock
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cta.copy_relationship_id = cr.id
    WHERE cta.trader_trade_id = p_trade_id
    AND cta.status = 'open'
  LOOP
    v_follower_pnl := COALESCE(v_allocation.allocated_amount, 0) * (p_pnl_percentage / 100.0);
    v_return_amount := GREATEST(0, COALESCE(v_allocation.allocated_amount, 0) + v_follower_pnl);

    -- Update allocation - this will trigger the cumulative_pnl update automatically
    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    v_wallet_type := CASE WHEN v_allocation.is_mock THEN 'mock' ELSE 'copy' END;

    SELECT COALESCE(balance, 0) INTO v_current_wallet_balance
    FROM wallets
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    IF v_current_wallet_balance IS NULL THEN
      INSERT INTO wallets (user_id, currency, wallet_type, balance)
      VALUES (v_allocation.follower_id, 'USDT', v_wallet_type, v_return_amount)
      ON CONFLICT (user_id, currency, wallet_type) 
      DO UPDATE SET balance = wallets.balance + v_return_amount, updated_at = NOW();
    ELSE
      UPDATE wallets
      SET 
        balance = COALESCE(balance, 0) + v_return_amount,
        updated_at = NOW()
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;
    END IF;

    -- Update copy_relationships - but DON'T update cumulative_pnl here
    -- The trigger will handle cumulative_pnl automatically
    UPDATE copy_relationships
    SET 
      current_balance = GREATEST(0, COALESCE(current_balance, 0) - COALESCE(v_allocation.allocated_amount, 0) + v_return_amount),
      total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl,
      updated_at = NOW()
    WHERE id = v_allocation.copy_relationship_id;

    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_close',
      'USDT',
      v_return_amount,
      'completed'
    );

    -- Distribute copy profit commission to VIP affiliates
    -- Only for real copy trading (not mock) and only if profitable
    IF NOT v_allocation.is_mock AND v_follower_pnl > 0 THEN
      v_commission_result := distribute_exclusive_copy_profit_commission(
        v_allocation.follower_id,
        v_follower_pnl,
        v_allocation.id
      );
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION close_trader_trade TO authenticated;
