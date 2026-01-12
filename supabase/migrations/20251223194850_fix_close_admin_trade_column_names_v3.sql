/*
  # Fix close_admin_trade Column Names

  1. Changes
    - Drop and recreate close_admin_trade(uuid, numeric, numeric) function
    - Update copy_trade_allocations to use correct column names
    - Change `pnl` to `realized_pnl`
    - Change `pnl_percent` to `pnl_percentage`

  2. Purpose
    - Fix error: column "pnl" of relation "copy_trade_allocations" does not exist
*/

DROP FUNCTION IF EXISTS close_admin_trade(uuid, numeric, numeric);

CREATE OR REPLACE FUNCTION close_admin_trade(
  p_position_id uuid,
  p_exit_price numeric,
  p_realized_pnl numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_allocation RECORD;
  v_follower_pnl numeric;
  v_return_amount numeric;
  v_wallet_type text;
  v_pnl_percentage numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM admin_trader_positions
  WHERE id = p_position_id
  AND status = 'open';

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Position not found or already closed');
  END IF;

  -- Calculate PNL percentage
  v_pnl_percentage := (p_realized_pnl / NULLIF(v_position.margin_used, 0)) * 100;

  -- Update the position
  UPDATE admin_trader_positions
  SET 
    status = 'closed',
    exit_price = p_exit_price,
    realized_pnl = p_realized_pnl,
    pnl_percentage = v_pnl_percentage,
    closed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_position_id;

  -- Update associated trader_trade if exists
  IF v_position.trader_trade_id IS NOT NULL THEN
    UPDATE trader_trades
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      pnl = p_realized_pnl,
      pnl_percent = v_pnl_percentage,
      closed_at = NOW()
    WHERE id = v_position.trader_trade_id;

    -- Distribute to all followers
    FOR v_allocation IN
      SELECT *
      FROM copy_trade_allocations
      WHERE trader_trade_id = v_position.trader_trade_id
      AND status = 'open'
    LOOP
      v_follower_pnl := v_allocation.allocated_amount * (v_pnl_percentage / 100.0);
      v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

      UPDATE copy_trade_allocations
      SET 
        status = 'closed',
        exit_price = p_exit_price,
        realized_pnl = v_follower_pnl,
        pnl_percentage = v_pnl_percentage,
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

        UPDATE copy_relationships
        SET 
          current_balance = current_balance + v_return_amount,
          total_pnl = COALESCE(total_pnl, 0) + v_follower_pnl,
          updated_at = NOW()
        WHERE id = v_allocation.copy_relationship_id;
      END IF;

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
        v_return_amount,
        'completed',
        NOW()
      );
    END LOOP;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Trade closed successfully');
END;
$$;

GRANT EXECUTE ON FUNCTION close_admin_trade(uuid, numeric, numeric) TO authenticated;
