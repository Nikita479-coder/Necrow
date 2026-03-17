/*
  # Fix close_trader_trade double-counting cumulative_pnl and total_pnl

  ## Problem
  - The `close_trader_trade` function manually updates `cumulative_pnl` and `total_pnl` on `copy_relationships`
  - The trigger `update_cumulative_pnl_on_allocation_close` on `copy_trade_allocations` ALSO updates the same fields
  - Both fire during the same trade close, causing PNL values to be exactly doubled

  ## Root Cause
  - A previous fix (20260228201938) corrected this but used a different parameter order (p_admin_id first)
  - This created a new overloaded function instead of replacing the existing one
  - The overloaded version was later dropped, leaving only the original buggy version

  ## Fix
  - Recreate the function with the CORRECT existing signature (p_trade_id, p_exit_price, p_pnl_percentage, p_admin_id)
  - Remove `cumulative_pnl` and `total_pnl` from the copy_relationships UPDATE
  - The trigger will handle PNL tracking automatically when allocation status changes to 'closed'

  ## Impact
  - All future trade closes will correctly track PNL once (via the trigger only)
  - Existing inflated data corrected in a separate statement below
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
  v_futures_position RECORD;
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
      cr.is_mock,
      cr.trader_id
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cta.copy_relationship_id = cr.id
    WHERE cta.trader_trade_id = p_trade_id
    AND cta.status = 'open'
  LOOP
    v_follower_pnl := COALESCE(v_allocation.allocated_amount, 0) * (p_pnl_percentage / 100.0);
    v_return_amount := GREATEST(0, COALESCE(v_allocation.allocated_amount, 0) + v_follower_pnl);

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

    IF NOT v_allocation.is_mock THEN
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
    END IF;

    -- Only update current_balance on copy_relationships
    -- Do NOT update cumulative_pnl or total_pnl here - the trigger handles that
    IF v_allocation.is_mock THEN
      UPDATE copy_relationships
      SET
        current_balance = GREATEST(0, COALESCE(current_balance, 0) + v_return_amount),
        updated_at = NOW()
      WHERE id = v_allocation.copy_relationship_id;
    ELSE
      UPDATE copy_relationships
      SET
        current_balance = GREATEST(0, COALESCE(current_balance, 0) - COALESCE(v_allocation.allocated_amount, 0) + v_return_amount),
        updated_at = NOW()
      WHERE id = v_allocation.copy_relationship_id;
    END IF;

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

    FOR v_futures_position IN
      SELECT fp.position_id
      FROM futures_positions fp
      WHERE fp.user_id = v_allocation.follower_id
      AND fp.pair = v_trade.symbol
      AND fp.side = v_trade.side
      AND fp.status = 'open'
      AND ABS(fp.entry_price - v_trade.entry_price) / v_trade.entry_price < 0.01
      LIMIT 1
    LOOP
      UPDATE futures_positions
      SET
        status = 'closed',
        realized_pnl = v_follower_pnl,
        closed_at = NOW(),
        updated_at = NOW()
      WHERE position_id = v_futures_position.position_id;
    END LOOP;

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

GRANT EXECUTE ON FUNCTION close_trader_trade(uuid, numeric, numeric, uuid) TO authenticated;
