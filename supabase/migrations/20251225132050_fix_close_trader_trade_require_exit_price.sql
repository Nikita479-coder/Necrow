/*
  # Fix close_trader_trade - Require Valid Exit Price

  1. Changes
    - Add validation to require non-null exit_price
    - Add validation to require non-null pnl_percentage
    - Ensure allocations are updated with exit_price

  2. Purpose
    - Fix issue where trades are being closed without exit price and PNL data
    - Ensure all closed trades have proper exit information
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
    SELECT *
    FROM copy_trade_allocations
    WHERE trader_trade_id = p_trade_id
    AND status = 'open'
  LOOP
    v_follower_pnl := COALESCE(v_allocation.allocated_amount, 0) * (p_pnl_percentage / 100.0);
    v_return_amount := COALESCE(v_allocation.allocated_amount, 0) + v_follower_pnl;

    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    SELECT 
      CASE WHEN is_mock THEN 'mock' ELSE 'copy' END
    INTO v_wallet_type
    FROM copy_relationships
    WHERE id = v_allocation.copy_relationship_id;

    IF v_return_amount > 0 THEN
      UPDATE wallets
      SET 
        balance = balance + v_return_amount,
        updated_at = NOW()
      WHERE user_id = v_allocation.follower_id
      AND currency = 'USDT'
      AND wallet_type = v_wallet_type;
    END IF;

    UPDATE copy_relationships
    SET 
      cumulative_pnl = COALESCE(cumulative_pnl, 0) + v_follower_pnl,
      current_balance = GREATEST(0, COALESCE(current_balance, 0) - COALESCE(v_allocation.allocated_amount, 0)),
      total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl
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
      COALESCE(v_return_amount, 0),
      'completed'
    );
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION close_trader_trade TO authenticated;
