/*
  # Fix close_trader_trade Balance Calculation Bug

  ## Problem
  The previous version had two critical bugs:
  1. Wallet balance only updated if v_return_amount > 0, skipping updates for losses
  2. current_balance was being SUBTRACTED by allocated_amount instead of ADDING the return_amount

  ## Changes
  1. **Fix wallet update**: Always update wallet balance (remove conditional)
  2. **Fix current_balance**: Add v_return_amount instead of subtracting allocated_amount
  3. **Ensure non-negative balances**: Use GREATEST(0, ...) to prevent negative balances

  ## Impact
  - Fixes issue where users' copy wallet balances were not being updated correctly
  - Ensures profitable trades properly increase balance
  - Ensures losses properly decrease balance (but not below 0)
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

    UPDATE copy_relationships
    SET 
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + v_follower_pnl,
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
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION close_trader_trade TO authenticated;
