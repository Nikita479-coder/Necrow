/*
  # Fix mock copy trade double-deduction on close

  1. Problem
    - When a mock copy trade is OPENED, `copy_relationships.current_balance` is
      decreased by the `allocated_amount` (correct).
    - When the same trade is CLOSED, `close_trader_trade` applies the formula
      `current_balance = current_balance - allocated_amount + return_amount`,
      subtracting `allocated_amount` a second time.
    - For real (non-mock) trades this is correct because `current_balance` is
      NOT decreased on open (the wallet is).
    - For mock trades the double-deduction causes the follower's displayed
      balance to drop far more than the actual PnL warrants.

  2. Fix
    - Split the `current_balance` update into two branches:
      - **Mock**: `current_balance += return_amount` (allocated_amount already
        subtracted at open)
      - **Real**: keep the existing formula
        `current_balance = current_balance - allocated_amount + return_amount`

  3. No data migration
    - Existing corrupted balances are not corrected here; a separate manual
      reconciliation can be run if needed.
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

    UPDATE copy_trade_allocations
    SET
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    IF NOT v_allocation.is_mock THEN
      SELECT COALESCE(balance, 0) INTO v_current_wallet_balance
      FROM wallets
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

      IF v_current_wallet_balance IS NULL THEN
        INSERT INTO wallets (user_id, currency, wallet_type, balance)
        VALUES (v_allocation.follower_id, 'USDT', 'copy', v_return_amount)
        ON CONFLICT (user_id, currency, wallet_type)
        DO UPDATE SET balance = wallets.balance + v_return_amount, updated_at = NOW();
      ELSE
        UPDATE wallets
        SET
          balance = COALESCE(balance, 0) + v_return_amount,
          updated_at = NOW()
        WHERE user_id = v_allocation.follower_id
        AND currency = 'USDT'
        AND wallet_type = 'copy';
      END IF;
    END IF;

    IF v_allocation.is_mock THEN
      UPDATE copy_relationships
      SET
        current_balance = GREATEST(0, COALESCE(current_balance, 0) + v_return_amount),
        total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl,
        updated_at = NOW()
      WHERE id = v_allocation.copy_relationship_id;
    ELSE
      UPDATE copy_relationships
      SET
        current_balance = GREATEST(0, COALESCE(current_balance, 0) - COALESCE(v_allocation.allocated_amount, 0) + v_return_amount),
        total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl,
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
