/*
  # Fix open_admin_trade Column References

  1. Changes
    - Fix references to realized_pnl -> pnl in open_admin_trade and close_admin_trade
    - Fix references to pnl_percentage -> pnl_percent in trader_trades table

  2. Notes
    - The trader_trades table uses 'pnl' not 'realized_pnl'
    - The trader_trades table uses 'pnl_percent' not 'pnl_percentage'
*/

-- Recreate open_admin_trade with correct column names
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
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  v_margin_percentage := (p_margin_used / 100000.0) * 100;

  INSERT INTO trader_trades (
    trader_id,
    symbol,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    pnl,
    pnl_percent,
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

      v_allocated_amount := (v_current_balance * v_margin_percentage) / 100.0;
      
      IF v_allocated_amount >= 1 AND v_current_balance >= v_allocated_amount THEN
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
        
        UPDATE wallets
        SET 
          balance = balance - v_allocated_amount,
          updated_at = NOW()
        WHERE user_id = v_follower.follower_id
        AND currency = 'USDT'
        AND wallet_type = v_wallet_type;

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

-- Recreate close_admin_trade with correct column names (close_trader_trade)
-- This is the function that closes trades
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

  SELECT * INTO v_trade
  FROM trader_trades
  WHERE id = p_trade_id
  AND status = 'open';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or already closed';
  END IF;

  v_pnl_usdt := v_trade.margin_used * (p_pnl_percentage / 100.0);

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
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);
    v_return_amount := v_allocation.allocated_amount + v_follower_pnl;

    UPDATE copy_trade_allocations
    SET 
      status = 'closed',
      exit_price = p_exit_price,
      pnl = v_follower_pnl,
      pnl_percent = p_pnl_percentage,
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
      current_balance = GREATEST(0, COALESCE(current_balance, '0')::numeric - v_allocation.allocated_amount),
      total_pnl = (COALESCE(total_pnl, '0')::numeric + v_follower_pnl)::text
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
